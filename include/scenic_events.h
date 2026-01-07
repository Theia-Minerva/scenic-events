#ifndef SCENIC_EVENTS_H
#define SCENIC_EVENTS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct se_stream_state {
    uint8_t stream_id;
    uint8_t has_last_seq;
    uint16_t _padding;
    uint32_t last_seq;
} se_stream_state;

enum se_events_error {
    SE_EVENTS_OK = 0,
    SE_EVENTS_END_OF_STREAM = 1,
    SE_EVENTS_INVALID_ARGS = 2,
    SE_EVENTS_INVALID_MAGIC = 3,
    SE_EVENTS_UNSUPPORTED_VERSION = 4,
    SE_EVENTS_TRUNCATED = 5,
    SE_EVENTS_OUTPUT_FULL = 6,
    SE_EVENTS_UNKNOWN_RECORD_KIND = 7,
    SE_EVENTS_STREAM_ALREADY_DECLARED = 8,
    SE_EVENTS_STREAM_NOT_DECLARED = 9,
    SE_EVENTS_STREAM_REGISTRY_FULL = 10,
    SE_EVENTS_SEQUENCE_NOT_MONOTONIC = 11,
    SE_EVENTS_NAMESPACE_TOO_LONG = 12,
    SE_EVENTS_PAYLOAD_TOO_LARGE = 13,
    SE_EVENTS_MISSING_HEADER = 14
};

enum se_record_kind {
    SE_RECORD_STREAM_DECL = 1,
    SE_RECORD_EVENT = 2
};

typedef struct se_stream_decl {
    uint8_t stream_id;
    const uint8_t* producer_namespace;
    uint8_t producer_namespace_len;
    uint32_t schema_id;
    uint32_t producer_version;
} se_stream_decl;

typedef struct se_event {
    uint8_t stream_id;
    uint32_t sequence;
    const uint8_t* payload;
    uint32_t payload_len;
} se_event;

typedef union se_record_data {
    se_stream_decl stream_decl;
    se_event event;
} se_record_data;

typedef struct se_record {
    enum se_record_kind kind;
    union se_record_data data;
} se_record;

typedef struct se_writer {
    uint8_t* buffer;
    size_t buffer_len;
    size_t offset;
    se_stream_state* registry;
    size_t registry_len;
    size_t registry_count;
    uint8_t wrote_header;
} se_writer;

typedef struct se_reader {
    const uint8_t* bytes;
    size_t bytes_len;
    size_t offset;
    se_stream_state* registry;
    size_t registry_len;
    size_t registry_count;
    uint8_t header_version;
} se_reader;

int se_writer_init(
    se_writer* writer,
    uint8_t* buffer,
    size_t buffer_len,
    se_stream_state* registry,
    size_t registry_len
);

int se_writer_write_header(se_writer* writer);

int se_writer_declare_stream(
    se_writer* writer,
    uint8_t stream_id,
    const uint8_t* producer_namespace,
    uint8_t producer_namespace_len,
    uint32_t schema_id,
    uint32_t producer_version
);

int se_writer_write_event(
    se_writer* writer,
    uint8_t stream_id,
    uint32_t sequence,
    const uint8_t* payload,
    uint32_t payload_len
);

const uint8_t* se_writer_bytes(const se_writer* writer, size_t* out_len);

int se_reader_init(
    se_reader* reader,
    const uint8_t* bytes,
    size_t bytes_len,
    se_stream_state* registry,
    size_t registry_len
);

uint8_t se_reader_header_version(const se_reader* reader);

int se_reader_next(se_reader* reader, se_record* out_record);

#ifdef __cplusplus
}
#endif

#endif
