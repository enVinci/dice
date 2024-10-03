#!/usr/bin/env python
from setuptools import setup, find_packages

setup(
    name='dicerolls',
    version='1.0',
    packages=find_packages(),
    entry_points={
        'console_scripts': [
            'dicerolls=dice.rolls:main',
        ],
    },
    install_requires=[
    ],
    author='enVinci',
    description='Utility for creating BIP39 mnemonics from user entropy and from QR codes, generating QR codes from mnemonics',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://github.com/enVinci/dice',
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
    ],
    python_requires='>=3.6',
)
