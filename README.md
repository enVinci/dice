# Rolls - Dice Roll Seed Generator

`rolls.py` is a Python script that allows you to create a seed from a dice roll. It can convert QR codes to BIP39 mnemonics, generate QR codes from BIP39 mnemonics, and print the BIP39 mnemonic table. The script also calculates the SHA-256 hash of the input and provides warnings for empty or short inputs.

## Features

- Convert a QR code (its encoded decimal payload) to a BIP39 mnemonic.
- Convert a BIP39 mnemonic to a QR code.
- Print the BIP39 mnemonic table.
- Calculate the SHA-256 hash of the input and provide entropy warnings.

## Requirements

- Python 3.x
- `zbarimg` and `zbarcam` for QR code reading.
- `qrencode` for generating QR codes.

## Installation

To install the required dependencies, you can use `pip`:

```bash
sudo apt-get install zbar-tools qrencode

```bash
pip3 install .
