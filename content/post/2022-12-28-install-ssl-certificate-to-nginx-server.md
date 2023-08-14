---
title: Install SSL certificate to Nginx server
date:  2022-12-28
tags: ["tutorial", "ssl", "nginx"]
---

Prerequisites:
- installed Nginx on the server
- SSL certificate provider chosen (this can be one of the domain/hosting providers like GoDaddy, Name.com etc.)


First of all we need to generate CSR to provide it to SSL certificate issuer (for example, one of the domain providers).

Open terminal on your server and run the command:
~~~sh
~$ openssl req -new -newkey rsa:2048 -nodes -keyout your-domain-name.key -out your-domain-name.csr
~~~

Interactively you will be prompted about additioal innformation like address, email, FQDN (full domain name) etc.

Finally we get two files: your-domain-name.key and  your-domain-name.csr in the current directory.

Open your-domain-name.csr file:

~~~sh
~$ cat your-domain-name.csr
~~~

and copy the content of the file and paste it to the CSR field of your SSL cerificate provider.

Then, after you have input data and CSR  to provider's form  and they get verified you will get SSL certificate, which consists of three files (or three text blocks): `server certificate``, CA intermediate certificate` and `CA root certificate`.
Let's copy all of them and paste all that stuff in one file, named `your-domain-name.pem`

Finally go to the  Nginx settings.

Let's create directory for our certificates:

~~~sh
~$ sudo mkdir /etc/nginx/ssl
~~~
 
Copy your earlier created your-domain-name.key  and you-domain-name.pem to /etc/nginx/ssl 

Then let's create configuration for our domain your-domain-name.

In directory /etc/nginx/sites-available run:

~~~sh
~$ cp default your-domain-name
~~~

that will copy all content of default settings to your custom configuration file.

then remove file default.

In /etc/nginx/sites-enabled remove @default symlink and create new one that points to your file /etc/nginx/sites-available/your-domain-name

~~~sh
~$ sudo ln -s ../sites-available/your-domain-name .
~~~

After that, open /etc/nginx/sites-available/your-domain-name and make some changes:

~~~sh
server {
	 listen 80 default_server;
         server_name your-domain-name.com www.your-domain-name.com;
         return 301 https://$server_name$request_uri;
}
 
server {
	listen 443 ssl;
        ssl_certificate    /etc/nginx/ssl/your-domain-name.pem;
        ssl_certificate_key    /etc/nginx/ssl/your-domain-name.key;
...
}
~~~

That's it. Restart nginx

~~~sh
$ sudo systemctl restart nginx
~~~

then open your site in browser, it should use https protocol. 

