from flask import Flask, render_template
import requests, os
app = Flask(__name__)
BACKEND_URL = os.environ.get('BACKEND_API_URL', 'http://localhost:5001/api/weather')
@app.route('/')
def home():
    weather_data, error = None, None
    try:
        response = requests.get(BACKEND_URL)
        response.raise_for_status()
        weather_data = response.json()
    except requests.exceptions.RequestException as e:
        error = f"Error: Could not connect to the backend service. {e}"
    return render_template('index.html', weather=weather_data, error=error)
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)