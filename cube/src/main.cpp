#include <Arduino.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include <PubSubClient.h>
#include <WiFi.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LEDS_DATA 2
#define LEDS_CLK 1
#define LEDN 25

#define IRON_PLATE_BELT "belt/[gps=-26.5,-36.5]/"

struct item_stats
{
	int start_led;
	CRGB color;
	const char *item_name;
	int moved;
	float potential_outputs;
	float potential_inputs;
};

static struct item_stats m_iron_plate_stats = {
    .start_led = 0,
    .color = {0, 140, 255},
    .item_name = "iron-plate",
};

static const int m_led_pins[] = {5, 7, 16, 18};

static CRGB FastLED_rgb[LEDN];

static WiFiClient m_wifi_client;
static PubSubClient m_pubsub_client(m_wifi_client);

// Gamma brightness lookup table <https://victornpb.github.io/gamma-table-generator>
// gamma = 2.20 steps = 256 range = 0-255
static const uint8_t gamma_lut[256] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7,
    8, 8, 8, 9, 9, 9, 10, 10, 11, 11, 11, 12, 12, 13, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18,
    18, 19, 19, 20, 20, 21, 22, 22, 23, 23, 24, 25, 25, 26, 26, 27, 28, 28, 29, 30, 30, 31, 32, 33,
    33, 34, 35, 35, 36, 37, 38, 39, 39, 40, 41, 42, 43, 43, 44, 45, 46, 47, 48, 49, 49, 50, 51, 52,
    53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 73, 74, 75, 76, 77,
    78, 79, 81, 82, 83, 84, 85, 87, 88, 89, 90, 91, 93, 94, 95, 97, 98, 99, 100, 102, 103, 105, 106,
    107, 109, 110, 111, 113, 114, 116, 117, 119, 120, 121, 123, 124, 126, 127, 129, 130, 132, 133,
    135, 137, 138, 140, 141, 143, 145, 146, 148, 149, 151, 153, 154, 156, 158, 159, 161, 163, 165,
    166, 168, 170, 172, 173, 175, 177, 179, 181, 182, 184, 186, 188, 190, 192, 194, 196, 197, 199,
    201, 203, 205, 207, 209, 211, 213, 215, 217, 219, 221, 223, 225, 227, 229, 231, 234, 236, 238,
    240, 242, 244, 246, 248, 251, 253, 255};

static void
show_potential(struct item_stats *stats)
{
	memset(&FastLED_rgb[stats->start_led], 0, 5 * sizeof(CRGB));
	FastLED_rgb[stats->start_led + 2] = stats->color * 0.5;

	float potential = stats->potential_inputs + stats->potential_outputs;
	float pot_norm = logf(fabsf(potential) / 2 + 1) / logf(10);
	Serial.println(pot_norm);
	if (pot_norm > 2)
		pot_norm = 2;

	CRGB outer_led = {};
	CRGB inner_led = {};
	if (pot_norm > 1) {
		outer_led = stats->color;
		outer_led.r *= (pot_norm - 1);
		outer_led.g *= (pot_norm - 1);
		outer_led.b *= (pot_norm - 1);
		inner_led = stats->color;
	} else {
		inner_led = stats->color;
		inner_led.r *= pot_norm;
		inner_led.g *= pot_norm;
		inner_led.b *= pot_norm;
	}

	outer_led.r = gamma_lut[outer_led.r];
	outer_led.g = gamma_lut[outer_led.g];
	outer_led.b = gamma_lut[outer_led.b];
	inner_led.r = gamma_lut[inner_led.r];
	inner_led.g = gamma_lut[inner_led.g];
	inner_led.b = gamma_lut[inner_led.b];
	Serial.println(outer_led.b);
	Serial.println(inner_led.b);

	if (potential < 0) {
		FastLED_rgb[stats->start_led] = outer_led;
		FastLED_rgb[stats->start_led + 1] = inner_led;
	} else {
		FastLED_rgb[stats->start_led + 4] = outer_led;
		FastLED_rgb[stats->start_led + 3] = inner_led;
	}

	FastLED.show();
}

static void
mqtt_callback(char *topic, uint8_t *data, size_t len)
{
	static char data_str[4096];
	memcpy(data_str, data, len);
	data_str[len] = 0;

	JsonDocument doc;
	DeserializationError err = deserializeJson(doc, data_str);
	if (err) {
		Serial.print("Call deserializeJson failed: ");
		Serial.println(err.f_str());
		return;
	}

	struct item_stats *stats = NULL;
	if (strstr(topic, IRON_PLATE_BELT)) {
		stats = &m_iron_plate_stats;
	}

	if (stats == NULL) {
		return;
	}

	Serial.println(topic);

	if (strstr(topic, "/moved")) {
		stats->moved = doc[stats->item_name];
	} else if (strstr(topic, "potential_outputs")) {
		stats->potential_outputs = doc[stats->item_name];
	} else if (strstr(topic, "potential_inputs")) {
		stats->potential_inputs = doc[stats->item_name];
		show_potential(stats);
	}
}

void
setup()
{
	Serial.begin(115200);
	while (!Serial) {
		; // wait for serial port to connect. Needed for native USB
	}

	FastLED.addLeds<APA102, LEDS_DATA, LEDS_CLK, BGR, DATA_RATE_MHZ(50)>(FastLED_rgb, LEDN);
	FastLED.setBrightness(255);
	FastLED.setDither(0);
	FastLED.show();

	WiFi.begin("ChataULesa", "ulesa529");

	while (true) {
		int status = WiFi.status();
		if (status == WL_CONNECTED)
			break;

		Serial.print("Connecting to wifi ");
		Serial.println(status);
		delay(500);
	}

	Serial.println(WiFi.localIP());

	m_pubsub_client.setServer("192.168.1.234", 1883);
	m_pubsub_client.setCallback(mqtt_callback);
	m_pubsub_client.subscribe("belt/#");
	m_pubsub_client.setBufferSize(4095);

	for (int i = 0; i < 4; i++)
		pinMode(m_led_pins[i], OUTPUT);
}

static void
handle_lightbar(void)
{
}

static void
handle_leds(void)
{
	digitalWrite(m_led_pins[0], m_iron_plate_stats.moved > 0);
}

void
loop()
{
	if (!m_pubsub_client.connected()) {
		Serial.println("Reconnecting mqtt");
		m_pubsub_client.connect("esp client");
		m_pubsub_client.subscribe("belt/#");
	}
	m_pubsub_client.loop();

	handle_lightbar();
	handle_leds();
}
