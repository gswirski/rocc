#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct device_discovery_handle device_discovery_handle;

typedef struct shutter_device shutter_device;

typedef struct RustByteSlice {
  const uint8_t *bytes;
  size_t len;
} RustByteSlice;

typedef struct device_discovery_observer {
  void *user;
  void (*destroy_user)(void *user);
  void (*discovered_device)(void *user, struct shutter_device *device);
} device_discovery_observer;

void shutter_set_logger(void (*log_function)(const char *c_str));

struct RustByteSlice shutter_device_name(struct shutter_device *handle);

struct RustByteSlice shutter_device_host(struct shutter_device *handle);

void shutter_device_release(struct shutter_device *handle);

struct device_discovery_handle *shutter_discovery_new(void);

void shutter_discovery_start(struct device_discovery_handle *handle,
                             struct device_discovery_observer observer);

void shutter_discovery_stop(struct device_discovery_handle *handle);

void shutter_discovery_poke(struct device_discovery_handle *handle);

void shutter_discovery_release(struct device_discovery_handle *handle);
