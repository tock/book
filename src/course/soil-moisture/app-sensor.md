# Soil Moisture Sensing Application

Tock applications are going to implement the main operation of the soil moisture
sensor. This submodule guides you through building the soil moisture sensor
capability itself (i.e., the ability to read the sensor and convert the readings
to soil moisture).

To get started copy an existing libtock-c application into a folder named
`soil-moisture-sensor`.

## Create a Function to Measure the Sensor

1.  We will start with writing a function to measure the sensor. Our first step
    is to power on the soil moisture sensor. We can do this by setting the GPIO
    pin. The kernel configured the first GPIO pin as the power pin, so we use
    index 0.

    ```c
    #include <libtock/peripherals/gpio.h>

    // Activate the soil moisture sensor and take a reading. Returns the soil
    // moisture in tenths of a percent.
    static uint32_t take_measurement(void) {
      // Power on the soil moisture sensor.
      libtock_gpio_set(0);

      // Sample the sensor

      // Disable the soil moisture sensor.
      libtock_gpio_clear(0);

      return 0;
    }
    ```

2.  To read the sensor we are going to use the ADC driver. Specifically, we are
    going to use the `libtocksync_adc_sample_buffer()` API. This interface will
    take multiple sensors and save them to a buffer we provide. To get a more
    reliable measurement, we are going to take 25 samples and average them.

    ```c
    #include <libtock-sync/peripherals/adc.h>
    #include <libtock/peripherals/gpio.h>

    // Activate the soil moisture sensor and take a reading. Returns the soil
    // moisture in tenths of a percent.
    static uint32_t take_measurement(void) {
      // Power on the soil moisture sensor.
      libtock_gpio_set(0);

      // Take 25 ADC readings.
      uint16_t samples[25];
      int err = libtocksync_adc_sample_buffer(0, 25, samples, 25);
      if (err != RETURNCODE_SUCCESS) {
        printf("Error sampling ADC: %d\n", err);
        return -1;
      }

      // Calculate the average of the ADC readings.
      uint32_t total = 0;
      for (int i = 0; i < 30; i++) {
        total += samples[i];
      }
      uint32_t average = total / 30;

      // Disable the soil moisture sensor.
      libtock_gpio_clear(0);

      return 0;
    }
    ```

3.  Next we calculate the soil moisture percentage. First we convert the
    readings into voltages. The ADC driver always returns 16 bit readings
    (regardless of the underlying resolution of the ADC). We can query for the
    ADC reference voltage to do the conversion.

    Then, to calculate the soil moisture, we convert the measured voltage to a
    soil moisture percentage in tenths of a percent. For now, we will use the
    constants that I found when I created a soil moisture sensor. Later we
    calibrate for your specific sensor.

    ```c
    #include <libtock-sync/peripherals/adc.h>
    #include <libtock/peripherals/gpio.h>

    // Activate the soil moisture sensor and take a reading. Returns the soil
    // moisture in tenths of a percent.
    static uint32_t take_measurement(void) {
      // Power on the soil moisture sensor.
      libtock_gpio_set(0);

      // Take 25 ADC readings.
      uint16_t samples[25];
      int err = libtocksync_adc_sample_buffer(0, 25, samples, 25);
      if (err != RETURNCODE_SUCCESS) {
        printf("Error sampling ADC: %d\n", err);
        return -1;
      }

      // Calculate the average of the ADC readings.
      uint32_t total = 0;
      for (int i = 0; i < 30; i++) {
        total += samples[i];
      }
      uint32_t average = total / 30;

      // Convert from ADC counts to millivolts. First get the ADC reference\
      // voltage.
      uint32_t reference_voltage;
      err = libtock_adc_command_get_reference_voltage(&reference_voltage);
      if (err != RETURNCODE_SUCCESS) {
        reference_voltage = 3300;
        printf("ADC no reference voltage, assuming 3.3V\n");
      }
      // The actual soil moisture sensor voltage in mV.
      uint32_t voltage_mv = (average * reference_voltage) / ((1 << 16) - 1);

      // Calculate the soil moisture percentage.
      uint32_t soil = 1797 - ((8111 * voltage_mv) / 10000);

      printf("[Soil Moisture Sensor]\n");
      printf("  voltage %ld.%03ldV\n", voltage_mv / 1000, voltage_mv % 1000);
      printf("  soil: %lu.%lu%%\n\n", soil / 10, soil % 10);

      // Disable the soil moisture sensor.
      libtock_gpio_clear(0);

      // And actually return the soil moisture reading.
      return soil;
    }
    ```

    We now have a sensing function!

## Setup a Soil Moisture Sensing IPC Service

To make the soil moisture data available to other applications, we will create
an inter-process communication (IPC) service that shared the soil moisture data.

1.  In the `main()` function, we will register our IPC service.

    We do this with the `ipc_register_service_callback()` API. The first
    argument is the name of our service. The second argument is the callback we
    get when clients notify us. The third argument is a user pointer we get in
    the callback. We do not need to use the third argument.

    ```c
    #include <libtock/kernel/ipc.h>

    int main(void) {
      int err;
      printf("[Soil Moisture] Sensor App\n");

      // Create an IPC service to make sensor readings available to other apps.
      err = ipc_register_service_callback("soil_moisture_sensor", ipc_client_registered, NULL);
      if (err != RETURNCODE_SUCCESS) {
        printf("Could not register %i ?\n", err);
        return -1;
      }

      // Wait for upcalls in a loop.
      while (1) yield();
    }
    ```

2.  Now we can define the callback function. The signature is
    `void callback(int, int, int, void*)`. This will get called with the process
    ID of the client, a pointer to the buffer the client shared with us, and the
    length of the buffer.

    ```c
    // Called when another app registers to our IPC service.
    static void ipc_client_registered(int pid,
    	                              int len,
    	                              int buf,
    	                              __attribute__ ((unused)) void* ud) {
    }
    ```

3.  We use the callback by saving the shared buffer. We will use this buffer to
    send the soil moisture reading to all subscribed clients.

    We need to create an array to save all clients.

    ```c
    struct sensor_client {
      int pid;
      uint8_t* buffer;
    };

    struct sensor_client clients[10];
    int client_count = 0;

    // Called when another app registers to our IPC service.
    static void ipc_client_registered(int pid, int len, int buf, __attribute__ ((unused)) void* ud) {
      uint8_t* buffer = (uint8_t*) buf;

      // Save the client in our static buffer.
      if (client_count == 10 || len < 4) return;
      clients[client_count].pid    = pid;
      clients[client_count].buffer = buffer;
      client_count += 1;
    }
    ```

## Create a Timer to Periodically Take and Share Measurements

Our final task for this app is to periodically take readings and send the
reading to all clients.

1.  In main, start a periodic timer.

    ```c
    #include <libtock/services/alarm.h>

    #define SAMPLE_INTERVAL_MS 5000

    libtock_alarm_repeating_t timer;

    int main(void) {
      int err;
      printf("[Soil Moisture] Sensor App\n");

      // Create an IPC service to make sensor readings available to other apps.
      err = ipc_register_service_callback("soil_moisture_sensor", ipc_client_registered, NULL);
      if (err != RETURNCODE_SUCCESS) {
        printf("Could not register %i ?\n", err);
        return -1;
      }

      // Set a timer to measure soil moisture periodically.
      libtock_alarm_repeating_every(SAMPLE_INTERVAL_MS, timer_cb, NULL, &timer);

      // Wait for upcalls in a loop.
      while (1) yield();
    }
    ```

2.  Now define the timer callback function that will be called on every alarm
    expiration. This function calls the `take_measurement()` function to collect
    a reading.

    ```c
    // Timer callback for starting a soil moisture reading.
    static void timer_cb(__attribute__ ((unused)) uint32_t now,
                         __attribute__ ((unused)) uint32_t scheduled,
                         __attribute__ ((unused)) void*    opaque) {
      uint32_t moisture_percent = take_measurement(reference_voltage);
    }
    ```

3.  Finally, we notify all subscribed IPC clients with the reading.

    ```c
    // Timer callback for starting a soil moisture reading.
    static void timer_cb(__attribute__ ((unused)) uint32_t now,
                         __attribute__ ((unused)) uint32_t scheduled,
                         __attribute__ ((unused)) void*    opaque) {
      uint32_t moisture_percent = take_measurement(reference_voltage);

      // Copy in to each IPC app's shared buffer.
      for (int i = 0; i < client_count; i++) {
        uint32_t* moisture_buf = (uint32_t*) clients[i].buffer;
        moisture_buf[0] = moisture_percent;
        ipc_notify_client(clients[i].pid);
      }
    }
    ```

## Checkpoint

We now have a sensing app! You should compile and flash this app to your board.

```
$ make
$ tockloader install
```

## Calibrating the Soil Moisture Sensor

To calibrate the sensor, run the `soil-moisture-sensor` app. On the console, you
should see something like:

```
$ tockloader listen

ADC reference voltage 3.317V

[Soil Moisture Sensor]
  voltage 1.675V
  soil: 43.9%

[Soil Moisture Sensor]
  voltage 1.682V
  soil: 43.3%
```

Hold the sensor in the air. Record the voltage.

Get a glass of water. Hold the sensor in the water. Record the voltage.

Calculate a linear fit equation from the two points: (air voltage in mV, 0) and
(water voltage in mV, 1000). This equation can then be used to convert the
voltage readings into soil moisture values (in tenths of a percent).
