# syntax=docker/dockerfile:1

FROM python:3.11-slim

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8888

COPY . .

ENTRYPOINT ["python"]
