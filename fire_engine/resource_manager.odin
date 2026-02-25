package fire_engine
import "base:runtime"
import "core:sync"
import chan "core:sync/chan"
import "core:thread"

ResourceLoadStatus :: enum {
	Unloaded,
	Queued,
	Loading,
	Ready,
	Failed,
}

WaveResource :: struct {
	path: string,
	target_sample_rate: u32,
	status: ResourceLoadStatus,
	load_error: WaveLoadError,
	ref_count: int,
	unload_when_ready: bool,
	audio: WaveAudio,
}

ResourceLoadRequest :: struct {
	path: string,
	target_sample_rate: u32,
}

ResourceManager :: struct {
	allocator: runtime.Allocator,
	resources: map[string]^WaveResource,
	lock: sync.Mutex,

	request_queue: chan.Chan(ResourceLoadRequest),
	worker_thread: ^thread.Thread,
	running: bool,

	init: proc(rm: ^ResourceManager),
	shutdown: proc(rm: ^ResourceManager),

	acquireWave: proc(rm: ^ResourceManager, path: string, target_sample_rate: u32 = 0, async: bool = true) -> ^WaveResource,
	releaseWave: proc(rm: ^ResourceManager, path: string) -> bool,

	getWaveStatus: proc(rm: ^ResourceManager, path: string) -> ResourceLoadStatus,
	getWaveRefCount: proc(rm: ^ResourceManager, path: string) -> int,
	getWaveAudio: proc(rm: ^ResourceManager, path: string) -> (^WaveAudio, bool),
}

createResourceManager :: proc(allocator := context.allocator) -> ^ResourceManager {
	rm := new(ResourceManager)
	rm.allocator = allocator
	rm.init = resourceManagerInit
	rm.shutdown = resourceManagerShutdown
	rm.acquireWave = resourceManagerAcquireWave
	rm.releaseWave = resourceManagerReleaseWave
	rm.getWaveStatus = resourceManagerGetWaveStatus
	rm.getWaveRefCount = resourceManagerGetWaveRefCount
	rm.getWaveAudio = resourceManagerGetWaveAudio
	rm.init(rm)
	return rm
}

resourceManagerInit :: proc(rm: ^ResourceManager) {
	rm.resources = make(map[string]^WaveResource)
	rm.request_queue, _ = chan.create_buffered(chan.Chan(ResourceLoadRequest), 128, rm.allocator)
	rm.running = true
	rm.worker_thread = thread.create_and_start_with_data(cast(rawptr)rm, resourceManagerWorkerProc)
}

resourceManagerShutdown :: proc(rm: ^ResourceManager) {
	if rm.running {
		rm.running = false
		chan.close(rm.request_queue)
	}

	if rm.worker_thread != nil {
		thread.join(rm.worker_thread)
		thread.destroy(rm.worker_thread)
		rm.worker_thread = nil
	}

	sync.mutex_lock(&rm.lock)
	for _, resource in rm.resources {
		resourceManagerDestroyResource(resource, rm.allocator)
	}
	sync.mutex_unlock(&rm.lock)

	chan.destroy(rm.request_queue)
	delete(rm.resources)
}

resourceManagerAcquireWave :: proc(rm: ^ResourceManager, path: string, target_sample_rate: u32 = 0, async: bool = true) -> ^WaveResource {
	sync.mutex_lock(&rm.lock)
	resource, exists := rm.resources[path]
	if exists {
		resource.ref_count += 1
		resource.unload_when_ready = false
		sync.mutex_unlock(&rm.lock)
		return resource
	}

	resource = new(WaveResource)
	resource.path = path
	resource.target_sample_rate = target_sample_rate
	resource.ref_count = 1
	resource.status = .Queued
	rm.resources[path] = resource
	sync.mutex_unlock(&rm.lock)

	if async {
		// If sending fails, channel was closed; mark as failed.
		if !chan.send(rm.request_queue, ResourceLoadRequest{path = path, target_sample_rate = target_sample_rate}) {
			sync.mutex_lock(&rm.lock)
			if existing, ok := rm.resources[path]; ok {
				existing.status = .Failed
				existing.load_error = .IoFailure
			}
			sync.mutex_unlock(&rm.lock)
		}
	} else {
		audio, load_error := loadWaveFile(path, target_sample_rate, rm.allocator)
		sync.mutex_lock(&rm.lock)
		if existing, ok := rm.resources[path]; ok {
			if load_error == .None {
				existing.audio = audio
				existing.status = .Ready
			} else {
				existing.status = .Failed
				existing.load_error = load_error
			}
		} else if load_error == .None {
			freeWaveAudio(&audio, rm.allocator)
		}
		sync.mutex_unlock(&rm.lock)
	}

	return resource
}

resourceManagerReleaseWave :: proc(rm: ^ResourceManager, path: string) -> bool {
	sync.mutex_lock(&rm.lock)
	resource, exists := rm.resources[path]
	if !exists {
		sync.mutex_unlock(&rm.lock)
		return false
	}

	if resource.ref_count > 0 {
		resource.ref_count -= 1
	}

	if resource.ref_count == 0 {
		if resource.status == .Loading || resource.status == .Queued {
			resource.unload_when_ready = true
			sync.mutex_unlock(&rm.lock)
			return true
		}

		delete_key(&rm.resources, path)
		sync.mutex_unlock(&rm.lock)
		resourceManagerDestroyResource(resource, rm.allocator)
		return true
	}

	sync.mutex_unlock(&rm.lock)
	return true
}

resourceManagerGetWaveStatus :: proc(rm: ^ResourceManager, path: string) -> ResourceLoadStatus {
	sync.mutex_lock(&rm.lock)
	resource, exists := rm.resources[path]
	if !exists {
		sync.mutex_unlock(&rm.lock)
		return .Unloaded
	}
	status := resource.status
	sync.mutex_unlock(&rm.lock)
	return status
}

resourceManagerGetWaveRefCount :: proc(rm: ^ResourceManager, path: string) -> int {
	sync.mutex_lock(&rm.lock)
	resource, exists := rm.resources[path]
	if !exists {
		sync.mutex_unlock(&rm.lock)
		return 0
	}
	ref_count := resource.ref_count
	sync.mutex_unlock(&rm.lock)
	return ref_count
}

resourceManagerGetWaveAudio :: proc(rm: ^ResourceManager, path: string) -> (^WaveAudio, bool) {
	sync.mutex_lock(&rm.lock)
	resource, exists := rm.resources[path]
	if !exists || resource.status != .Ready {
		sync.mutex_unlock(&rm.lock)
		return nil, false
	}
	audio := &resource.audio
	sync.mutex_unlock(&rm.lock)
	return audio, true
}

resourceManagerWorkerProc :: proc(data: rawptr) {
	rm := cast(^ResourceManager)data

	for {
		request, ok := chan.recv(rm.request_queue)
		if !ok {
			break
		}

		sync.mutex_lock(&rm.lock)
		resource, exists := rm.resources[request.path]
		if !exists {
			sync.mutex_unlock(&rm.lock)
			continue
		}

		if resource.ref_count == 0 {
			delete_key(&rm.resources, request.path)
			sync.mutex_unlock(&rm.lock)
			resourceManagerDestroyResource(resource, rm.allocator)
			continue
		}

		resource.status = .Loading
		resource.target_sample_rate = request.target_sample_rate
		sync.mutex_unlock(&rm.lock)

		audio, load_error := loadWaveFile(request.path, request.target_sample_rate, rm.allocator)

		should_destroy := false
		sync.mutex_lock(&rm.lock)
		existing, still_exists := rm.resources[request.path]
		if still_exists {
			if load_error == .None {
				existing.audio = audio
				existing.status = .Ready
				existing.load_error = .None
			} else {
				existing.status = .Failed
				existing.load_error = load_error
			}

			if existing.ref_count == 0 || existing.unload_when_ready {
				delete_key(&rm.resources, request.path)
				should_destroy = true
			}
		} else if load_error == .None {
			freeWaveAudio(&audio, rm.allocator)
		}
		sync.mutex_unlock(&rm.lock)

		if should_destroy {
			resourceManagerDestroyResource(existing, rm.allocator)
		}
	}
}

resourceManagerDestroyResource :: proc(resource: ^WaveResource, allocator := context.allocator) {
	if resource == nil {
		return
	}
	freeWaveAudio(&resource.audio, allocator)
	free(resource, allocator)
}
