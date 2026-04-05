# 🚀 Quick Start Guide for Backend (Go) Developers

Welcome to the Niramaya-Net ML Layer! 

As the Go/Backend developer, **you do not need to know any machine learning or Python to work with this.** This microservice acts as a simple "black box" API: you send it JSON containing health data, and it sends back JSON containing routing priorities and wait times.

## 1. How to Start the ML Server Locally
You need this running on your machine in the background while you build the Go backend so your HTTP requests have somewhere to go.

**Prerequisites:** Ensure you have Python installed.

1. Open your terminal and navigate to the `ml` folder:
   ```bash
   cd "queue optimization\ml"
   ```
2. Install the required libraries (only need to do this once):
   ```bash
   pip install -r requirements.txt
   ```
3. Start the server:
   ```bash
   python app.py
   ```

**That's it!** The ML engine is now running locally on `http://localhost:8001`. You can minimize that terminal window and forget about it. 

---

## 2. How to Talk to the API
Since the ML is running, you just send normal HTTP requests to it from your Go code using the standard `net/http` library.

**Where is the API Documentation?**
Please open the strictly defined API contract here:  
👉 `docs/ml_integration_guide.md`

This guide shows you exactly what JSON you need to `POST` to get priority scores, and what the JSON response will look like.

## 3. How to Test It (Postman)
If you want to test the endpoints before you write your Go HTTP clients, I have prepared a full suite of edge cases in Postman.

1. Open Postman.
2. Import the collection found at: `docs/Hospital_Queue_Tests.postman_collection.json`
3. Hit "Send" on any of the test cases (like *Silent Inversion* or *Accidental Bypass*) to see exactly how the ML responds to different patient scenarios.
