# Use Amazon Linux 2 base image
FROM amazonlinux:2

# Enable Python 3.11 and install required packages
RUN amazon-linux-extras enable python3.11 && \
    amazon-linux-extras install -y python3.11 && \
    yum install -y python3-pip unzip curl docker && \
    yum clean all

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# Set working directory and copy app code
WORKDIR /app
COPY . /app

# (Optional) Install Python dependencies
# RUN pip3 install --no-cache-dir -r requirements.txt

# Set container entrypoint
CMD ["python3", "pipeline.py"]

