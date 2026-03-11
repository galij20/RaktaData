#!/bin/bash

cp server/.env.example server/.env
echo "Copied .env.example to .env. Please review and update the .env file with your actual configuration values."

cd server
npm install
npm run build
echo "Server build complete. You can now start the server with 'npm start' or 'npm run dev'."  


npm run dev 