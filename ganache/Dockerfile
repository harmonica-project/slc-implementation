# node:10 will be our base image to create this image
FROM node:10
# Set the /app directory as working directory
WORKDIR /app
# Install ganache-cli globally
RUN npm install -g ganache-cli
# Set the default command for the image
EXPOSE 8545

# Launch Ganache with our predefined accounts
CMD ganache-cli -h 0.0.0.0 \
--account="0xcac4e35c5ac37b99265d3ac49cbaa9a2b95d4b9ed7d7fad0c101b6b1af154058,10000000" \
--account="0xd756fe7edd293fbedcba2661d5d9938d66e92c998a98e4619d7506bca1f272f6,10000000" \
--account="0xa9bc6a5b090f501eb573e541f72469892830e36da8c922e30615404878348b87,10000000" \
--account="0x9aa6e3fcd81f7917c851a89fa2a5290efd056c6ff5fad09525e677e66e394273,10000000" \