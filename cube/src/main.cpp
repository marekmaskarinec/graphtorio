#include <Arduino.h>
#include <FastLED.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

#define LEDS_DATA 2
#define LEDS_CLK 1

#define LEDN 25

static CRGB FastLED_rgb[LEDN];

static WiFiClient m_wifi_client;
static PubSubClient m_pubsub_client(m_wifi_client);

static int m_belt_val;

static void mqtt_callback(char *topic, uint8_t *data, size_t len) {
    static char data_str[64];
    memcpy(data_str, data, len);
    data_str[len] = 0;
    Serial.println(data_str);
    int value;
    if (sscanf(data_str, "{\"value\":%d}", &value) != 1) {
        Serial.println("Failed to parse MQTT data");
        return;
    }

    m_belt_val = value;

    for (int i = 0; i < 5 * (value / 15.f); i++) {
        FastLED_rgb[i].r = 0;
        FastLED_rgb[i].g = 140;
        FastLED_rgb[i].b = 255;
    }

    FastLED.show();
}

void setup() {
    Serial.begin(115200);
    while (!Serial) {
        ; // wait for serial port to connect. Needed for native USB
    }

    FastLED.addLeds<APA102, LEDS_DATA, LEDS_CLK, BGR,DATA_RATE_MHZ(50)>(FastLED_rgb,LEDN);
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
}

void loop() {
    if (!m_pubsub_client.connected()) {
        Serial.println("Reconnecting mqtt");
        m_pubsub_client.connect("esp client");
        m_pubsub_client.subscribe("belt/#");
    }
    m_pubsub_client.loop();
}
