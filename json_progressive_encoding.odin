package main

import json "core:encoding/json"
import "core:bufio"
import os "core:os"

ProgressivePerson :: struct {
    name: string `json:"name"`,
    age: u32 `json:"-"`,
    full_name: string `json:"-"`,
}

me :: ProgressivePerson{
    name = "Brandon",
    age = 40,
}

somebody :: ProgressivePerson{
    name = "Unknown",
    age = 0,
}

ProgressivePeoplePayload :: struct {
    me: ProgressivePerson,
    somebody: ProgressivePerson,
}

progressivePersonRebuildDerivedFields :: proc(p: ^ProgressivePerson) {
    if p == nil {
        return
    }
    p.full_name = p.name
}

progressivePeoplePayloadRebuildDerivedFields :: proc(payload: ^ProgressivePeoplePayload) {
    if payload == nil {
        return
    }
    progressivePersonRebuildDerivedFields(&payload.me)
    progressivePersonRebuildDerivedFields(&payload.somebody)
}

EncodeTest :: proc(file_path: string) {
    mode := 0
    when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    }

    fd, open_err := os.open(file_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, mode)
    if open_err != nil {
        return
    }
    defer os.close(fd)

    writer: bufio.Writer
    bufio.writer_init(&writer, os.stream_from_handle(fd))
    defer bufio.writer_destroy(&writer)

    stream := bufio.writer_to_stream(&writer)
    marshal_opt := json.Marshal_Options{pretty = true}

    payload := ProgressivePeoplePayload{
        me = me,
        somebody = somebody,
    }

    if err := json.marshal_to_writer(stream, payload, &marshal_opt); err != nil {
        return
    }

    _ = bufio.writer_flush(&writer)
}

DecodeTest :: proc(file_path: string) -> (payload: ProgressivePeoplePayload, ok: bool) {
    data, read_ok := os.read_entire_file(file_path)
    if !read_ok {
        return ProgressivePeoplePayload{}, false
    }
    defer delete(data)

    if err := json.unmarshal(data, &payload); err != nil {
        return ProgressivePeoplePayload{}, false
    }

    progressivePeoplePayloadRebuildDerivedFields(&payload)

    return payload, true
}

DecodePeople :: proc(file_path: string) -> (decoded_me: ProgressivePerson, decoded_somebody: ProgressivePerson, ok: bool) {
    payload, success := DecodeTest(file_path)
    if !success {
        return ProgressivePerson{}, ProgressivePerson{}, false
    }
    return payload.me, payload.somebody, true
}