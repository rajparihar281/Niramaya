🏥 Niramaya-Net National Grid — Local Setup Guide

This guide walks you through setting up and running the Niramaya-Net National Grid locally. The system consists of three core layers:

🔗 Blockchain Node (Hardhat)
⚙️ Go Logistics Engine
🖥️ Vite Admin Panel
📦 1. Prerequisites

Ensure your system has the following installed:

Go (v1.21 or higher)
Node.js (v18 or higher) & npm

Hardhat

npm install --save-dev hardhat
PostgreSQL with PostGIS Extension
Make sure PostGIS is enabled in your database.
🚀 2. Execution Sequence

Follow the steps in order to properly synchronize all services.

🔗 Step 1: Ignite the Blockchain (Hardhat)

Navigate to the smart contracts directory:

cd niramaya-contracts

Start the local blockchain node:

npx hardhat node

📍 This will start a local RPC server at:

http://127.0.0.1:8545
📜 Deploy Smart Contract

Open a new terminal and run:

npx hardhat run scripts/deploy.js --network localhost

⚠️ Important:

Copy the Contract Address from the output
Example:

0x5FbDB2315678afecb367f032d93F642f64180aa3
⚙️ Step 2: Start the Go Logistics Engine

Navigate to the backend directory:

cd niramaya-backend

Update your .env file with:

Contract Address (from Step 1)
Supabase credentials

Then run:

go mod tidy
go run main.go

📍 The backend will start at:

http://localhost:10000
🖥️ Step 3: Launch the Admin Command Centre

Navigate to the admin panel:

cd niramaya-admin

Install dependencies:

npm install

Start the development server:

npm run dev

📍 Access the dashboard at:

http://localhost:5173

✅ Ensure the "Blockchain Status" indicator turns green

📱 Step 4: Mobile App Sync (Optional / Testing)

To allow Flutter apps (Patient/Driver) to communicate with your local backend, use ngrok.

Run:

ngrok http 10000

This will generate a public URL like:

https://abc123.ngrok.io
🔧 Update Flutter Configuration

In your Flutter app, update:

BASE_URL = "https://abc123.ngrok.io";
