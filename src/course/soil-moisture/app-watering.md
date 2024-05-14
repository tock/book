Soil Moisture Watering Instructions Application
=================================



Our third app signals to people when they need to water the plant.

Copy an existing libtock-c application into a folder named
`soil-moisture-watering`.


### Display "Water Me!"

Our first step will be to create a function to display "Water Me!" when
the plant needs water. This looks similar to displaying the moisture level.

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

We will use the `sensor_service.c` file we created for the previous app.
Create a symlink from the other app.

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



