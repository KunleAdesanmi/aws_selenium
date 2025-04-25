# Use a base image
FROM python:3.8-slim

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container
COPY . /app

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Run the application
CMD ["python", "app.py"]
