#!/bin/bash

sudo apt-get update
sudo apt-get install -y nodejs npm mongodb

git clone https://github.com/Jacreator/NestJS_UserAuthAndReset
cd nodejs-app
npm install
node server.js
