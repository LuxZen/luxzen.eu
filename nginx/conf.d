server {
    listen 80;
    server_name luxzen.eu www.luxzen.eu;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name luxzen.eu www.luxzen.eu;

    ssl_certificate /etc/letsencrypt/live/luxzen.eu/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/luxzen.eu/privkey.pem;

    location / {
        proxy_pass http://ghost:2368;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
