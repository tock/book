## [APP2] Data Display App

The second app will display the soil moisture reading on the screen.

Copy an existing libtock-c application into a folder named
`soil-moisture-display`.

### Display Soil Moisture on the Screen

We start by implementing a function that displays the soil moisture on the
screen.

1.  The first step is to put together a string to display on the screen.

    ```c
    static void show_moisture(uint32_t reading) {
      char buf[30];
      uint32_t whole   = reading / 10;
      uint32_t decimal = reading % 10;
      snprintf(buf, 30, "Soil Moisture: %lu.%01lu%%", whole, decimal);
    }
    ```

2.  Now we will center the text on the display and write it to the screen.

    ```c
    u8g2_t u8g2;

    int display_width;
    int display_height;

    static void show_moisture(uint32_t reading) {
      char buf[30];
      uint32_t whole   = reading / 10;
      uint32_t decimal = reading % 10;
      snprintf(buf, 30, "Soil Moisture: %lu.%01lu%%", whole, decimal);

      int strwidth = u8g2_GetUTF8Width(&u8g2, buf);

      int y_center = display_height / 2;
      int x        = max((display_width / 2) - (strwidth / 2), 0);

      u8g2_ClearBuffer(&u8g2);
      u8g2_DrawStr(&u8g2, x, y_center, buf);
      u8g2_SendBuffer(&u8g2);
    }
    ```

### Connect to the IPC Service

Next we connect with the IPC service to get soil moisture data. We will put this
in a new file (`sensor_service.c`) so it is easier to re-use for other apps.

1.  Connecting to an IPC service takes four steps:

    1. Discovering the service.
    2. Registering a callback.
    3. Sharing a buffer with the service.
    4. Notifying the service we want to use it.

    Create a function named `connect_to_sensor_service()` and use it to connect
    to the IPC service.

    ```c
    returncode_t connect_to_sensor_service(char* ipc_buf) {
      int err;
      size_t svc_num = 0;

      // Find the sensing service.
      err = ipc_discover("soil_moisture_sensor", &svc_num);
      if (err < 0) {
        printf("No soil moisture service\n");
        return err;
      }
      // Setup our local callback for when new sensor data is ready.
      err = ipc_register_client_callback(svc_num, ipc_callback, NULL);
      if (err < 0) {
        printf("No ipc_register_client_callback\n");
        return err;
      }
      // Share a buffer with the service to send us data.
      err = ipc_share(svc_num, ipc_buf, 64);
      if (err < 0) {
        printf("No ipc_share\n");
        return err;
      }
      // Notify that we exist so the service will send us data.
      err = ipc_notify_service(svc_num);
      if (err < 0) {
        printf("No ipc_notify_service\n");
        return err;
      }

      return RETURNCODE_SUCCESS;
    }
    ```

2.  Create a callback function to receive the events when data is available.

    ```c
    static void ipc_callback(__attribute__ ((unused)) int   pid,
                             __attribute__ ((unused)) int   len,
                             __attribute__ ((unused)) int   arg2,
                             __attribute__ ((unused)) void* ud) {
      uint32_t* moisture_buf    = (uint32_t*) ipc_buf;
      uint32_t moisture_reading = moisture_buf[0];
      callback(moisture_reading);
    }
    ```

3.  Save a callback for the top-level application and provide the sensor
    reading.

    ```c
    static sensor_service_callback _callback;
    static char* _ipc_buf;

    static void ipc_callback(__attribute__ ((unused)) int   pid,
                             __attribute__ ((unused)) int   len,
                             __attribute__ ((unused)) int   arg2,
                             __attribute__ ((unused)) void* ud) {
      uint32_t* moisture_buf    = (uint32_t*) ipc_buf;
      uint32_t moisture_reading = moisture_buf[0];
      callback(moisture_reading);
    }

    returncode_t connect_to_sensor_service(char* ipc_buf, sensor_service_callback cb) {
      int err;
      size_t svc_num = 0;

      // Save the callback to use when we get notified.
      _callback = cb;
      _ipc_buf = ipc_buf;

      // Find the sensing service.
      err = ipc_discover("soil_moisture_sensor", &svc_num);
      if (err < 0) {
        printf("No soil moisture service\n");
        return err;
      }
      // Setup our local callback for when new sensor data is ready.
      err = ipc_register_client_callback(svc_num, ipc_callback, NULL);
      if (err < 0) {
        printf("No ipc_register_client_callback\n");
        return err;
      }
      // Share a buffer with the service to send us data.
      err = ipc_share(svc_num, ipc_buf, 64);
      if (err < 0) {
        printf("No ipc_share\n");
        return err;
      }
      // Notify that we exist so the service will send us data.
      err = ipc_notify_service(svc_num);
      if (err < 0) {
        printf("No ipc_notify_service\n");
        return err;
      }

      return RETURNCODE_SUCCESS;
    }
    ```

4.  Finally, create a header file (`sensor_service.h`) for our IPC service.

    ```c
    #pragma once

    #include <libtock/tock.h>

    #ifdef __cplusplus
    extern "C" {
    #endif

    typedef void (*sensor_service_callback)(uint32_t);

    returncode_t connect_to_sensor_service(char* ipc_buf, sensor_service_callback cb);

    #ifdef __cplusplus
    }
    #endif
    ```

### Initialize the Screen

In the `main()` function, we will setup the screen.

1.  We initialize the screen, choose a font, and clear the display.

    ```c
    #include <u8g2-tock.h>
    #include <u8g2.h>

    int main(void) {
      int err;

      printf("[Soil Moisture Data] Display Readings\n");

      err = u8g2_tock_init(&u8g2);
      if (err) {
        printf("Could not init screen\n");
        return -2;
      }

      display_width  = u8g2_GetDisplayWidth(&u8g2);
      display_height = u8g2_GetDisplayHeight(&u8g2);

      u8g2_SetFont(&u8g2, u8g2_font_helvR08_tf);
      u8g2_SetFontPosCenter(&u8g2);

      u8g2_ClearBuffer(&u8g2);
      u8g2_SendBuffer(&u8g2);

      while (1) yield();
    }
    ```

2.  Use our sensor service to get data from other application.

    ```c
    #include <u8g2-tock.h>
    #include <u8g2.h>

    char ipc_buf[64] __attribute__((aligned(64)));

    static void ipc_callback(uint32_t moisture_reading) {
      show_moisture(moisture_reading);
    }

    int main(void) {
      int err;

      printf("[Soil Moisture Data] Display Readings\n");

      err = u8g2_tock_init(&u8g2);
      if (err) {
        printf("Could not init screen\n");
        return -2;
      }

      display_width  = u8g2_GetDisplayWidth(&u8g2);
      display_height = u8g2_GetDisplayHeight(&u8g2);

      u8g2_SetFont(&u8g2, u8g2_font_helvR08_tf);
      u8g2_SetFontPosCenter(&u8g2);

      u8g2_ClearBuffer(&u8g2);
      u8g2_SendBuffer(&u8g2);

      err = connect_to_sensor_service(ipc_buf, ipc_callback);
      if (err != RETURNCODE_SUCCESS) return -1;

      while (1) yield();
    }
    ```

### Wrap Up - Second App

You can now compile and load this app!

## [APP3] Watering Instructions App

Our third app signals to people when they need to water the plant.

Copy an existing libtock-c application into a folder named
`soil-moisture-watering`.

### Display "Water Me!"

Our first step will be to create a function to display "Water Me!" when the
plant needs water. This looks similar to displaying the moisture level.

```c
u8g2_t u8g2;

int display_width;
int display_height;

// Notify viewers to water the plant!
static void water_me(void) {
  char buf[20];
  snprintf(buf, 20, "Water Me!");

  int strwidth = u8g2_GetUTF8Width(&u8g2, buf);

  int y_center = display_height / 2;
  int x        = max((display_width / 2) - (strwidth / 2), 0);

  u8g2_ClearBuffer(&u8g2);
  u8g2_DrawStr(&u8g2, x, y_center, buf);
  u8g2_SendBuffer(&u8g2);
}
```

### Connect to the IPC Service

We will use the `sensor_service.c` file we created for the previous app. Create
a symlink from the other app.

```
ln -s ../soil-moisture-display/sensor_service.* .
```

1.  Connect to the IPC service:

    ```c
    char ipc_buf[64] __attribute__((aligned(64)));

    int main(void) {
      int err;
      printf("[Soil Moisture Instructions] When to water\n");

      err = connect_to_sensor_service(ipc_buf, ipc_callback);
      if (err != RETURNCODE_SUCCESS) return -1;

      while (1) yield();
    }
    ```

2.  Create the IPC callback. This will call `water_me()` if the soil moisture is
    low enough.

    ```c
    // Water if the soil moisture is below 45.5%.
    #define WATER_THRESHOLD_TENTH_PERCENT 455

    static void ipc_callback(uint32_t moisture_reading) {
      if (moisture_reading < WATER_THRESHOLD_TENTH_PERCENT) {
        water_me();
      } else {
        // No water needed, just clear the screen.
        u8g2_ClearBuffer(&u8g2);
        u8g2_SendBuffer(&u8g2);
      }
    }
    ```

### Initialize the screen

```c
int main(void) {
  int err;
  printf("[Soil Moisture Instructions] When to water\n");

  u8g2_tock_init(&u8g2);

  display_width  = u8g2_GetDisplayWidth(&u8g2);
  display_height = u8g2_GetDisplayHeight(&u8g2);

  u8g2_SetFont(&u8g2, u8g2_font_helvR14_tf);
  u8g2_SetFontPosCenter(&u8g2);

  err = connect_to_sensor_service(ipc_buf, ipc_callback);
  if (err != RETURNCODE_SUCCESS) return -1;

  while (1) yield();
}
```

### Wrap Up - Third App

We now have an app to notify when a plant needs watering!
