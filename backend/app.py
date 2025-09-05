from flask import Flask, jsonify
app = Flask(__name__)
@app.route('/api/weather')
def get_weather():
    weather_data = {"city": "Lahore", "temperature": 34, "condition": "Sunny"}
    return jsonify(weather_data)   
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)