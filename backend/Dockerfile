FROM python:3.9-slim

WORKDIR /app

# Pehle sirf requirements file copy karein
COPY requirements.txt .

# Ab dependencies install karein
RUN pip install -r requirements.txt

# Aakhir mein baaqi code copy karein
COPY . .

EXPOSE 5001

CMD ["python", "app.py"]
