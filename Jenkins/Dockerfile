FROM node:latest

RUN npm install -g @angular/cli && mkdir -p /home/proj/app-front

WORKDIR /home/proj

RUN git clone https://github.com/bogdan-domanskiy/app-front

WORKDIR /home/proj/app-front


RUN npm install
CMD ng serve --host 0.0.0.0
