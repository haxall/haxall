# syntax=docker/dockerfile:1

FROM python:3-slim

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8888

COPY . .

# this doesn't work?
# docker run --rm hxpy -m hxpy -p 8888 -k foo --host 0.0.0.0

# this might not work in production
# docker run -t --rm hxpy -m hxpy -p 8888 -k foo --host host.docker.internal

ENTRYPOINT ["python"]
#CMD ["python"]
#CMD ["/bin/bash"]
