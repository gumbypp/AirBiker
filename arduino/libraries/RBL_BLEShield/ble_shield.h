/*

Copyright (c) 2012, 2013 RedBearLab

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

#ifndef  _BLE_SHIELD_H
#define _BLE_SHIELD_H

// forward declare
struct hal_aci_data_t;
//struct services_pipe_type_mapping_t;  // cannot forward declare since this is a typedef

void ble_begin(hal_aci_data_t *setup_msgs, uint8_t nb_setup_messages,
    void /*services_pipe_type_mapping_t*/ *services_pipe_type_mapping, uint8_t number_of_pipes,
    uint8_t pipe_uart_over_btle_uart_tx_tx, uint8_t pipe_uart_over_btle_uart_rx_rx,
    uint8_t pipe_device_information_hardware_revision_string_set);
void ble_write(unsigned char data);
void ble_write_bytes(unsigned char *data, unsigned char len);
uint8_t ble_get_tx_buffer_len();
void ble_do_events();
int ble_read();
unsigned char ble_available();
unsigned char ble_connected(void);
void ble_set_pins(uint8_t reqn, uint8_t rdyn);

#endif

