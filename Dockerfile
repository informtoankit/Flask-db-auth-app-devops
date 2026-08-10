
# Base image download
FROM python:3.12-slim
 
# Install required system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*
 
# Set working directory
WORKDIR /app
 
# Copy requirements first
COPY requirements.txt .
 
# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
 
# Copy project files
COPY . .
 
# Expose Flask app port
EXPOSE 5000
 
# Run the Flask app
CMD ["python", "run.py"]
 