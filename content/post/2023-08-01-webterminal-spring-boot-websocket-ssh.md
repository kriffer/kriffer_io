---
title: Creating Web UI terminal application with Spring Boot 3, Websocket and JSch SSH2 
date:  2023-08-01
tags: ["java", "spring", "tutorial", "websocket", "ssh"]
---


### Prerequisites
- Java 17 (I personally use OpenJDK 17, builds of that are available here https://www.azul.com/downloads/?version=java-17-lts&package=jdk#zulu)
- Spring Boot 3 initial starter application (Bootstrap it with https://start.spring.io/). Make sure to add as dependencies:
lombok, websocket

In addition we'll need to add a dependency for JSch library

```xml
        <dependency>
            <groupId>com.jcraft</groupId>
            <artifactId>jsch</artifactId>
            <version>0.1.55</version>
        </dependency>
```
        
The main idea is to have a Spring Boot application that has server and web client parts. 
- Client sends the command to the server via Websocket protocol. 
- The server receives this command and dispatch it to the remote machine using ssh. 
- The server receives the ssh response from the remote machine and dispatch it to the client via Websocket session.

Thus we'll have a simple ssh terminal running in web.
 


### Initial configuration

In order to allow Spring Security handle the access and at the same time avoid unnecessary restrictive configuration we create a basic security configuration where we grant access to all the endpoints (we do not aim to set up any authentication at this moment)

```java
package io.kriffer.webterminal.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

import static org.springframework.security.config.Customizer.withDefaults;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    protected SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.cors(withDefaults())
                .csrf(AbstractHttpConfigurer::disable)
                .authorizeHttpRequests
                        ((requests) -> requests.
                                anyRequest().
                                permitAll());

        return http.build();
    }
}
```


Then its time to add configuration for our Websocket server:

```java
package io.kriffer.webterminal.config;

import io.kriffer.webterminal.controllers.WebSocketHandler;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

	@Autowired
	WebSocketHandler webSocketHandler;

	@Override
	public void registerWebSocketHandlers(WebSocketHandlerRegistry webSocketHandlerRegistry) {
		webSocketHandlerRegistry.addHandler(webSocketHandler, "/console").setAllowedOrigins("*");
	}
}

```

As we can see we are setting the `/console` path for handling client connection and receiving Websockets messages.


### Handlers and models


First we need a model class that represents the Websocket request object that will be mapped to the request message from client to server:

```java
package io.kriffer.webterminal.model;

import lombok.*;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@EqualsAndHashCode
public class Request {

    private String username;
    private String password;
    private String host;
    private String sessionUser;
    private int port;
    private String command;
    private String res;

}
```


The Request object will be handled in Websocket handler, which is responsible also for sending a response back to the client:

```java
package io.kriffer.webterminal.controllers;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectWriter;
import com.jcraft.jsch.ChannelExec;
import com.jcraft.jsch.JSch;
import com.jcraft.jsch.Session;
import io.kriffer.webterminal.model.Request;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.*;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;


@Component
@Slf4j
public class WebSocketHandler extends TextWebSocketHandler {

    private Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private ObjectWriter objectWriter;

    public WebSocketHandler(ObjectMapper objectMapper) {
        this.objectWriter = objectMapper.writerWithDefaultPrettyPrinter();
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable throwable) {
        log.error("error occured at sender " + session, throwable);
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        log.info(String.format("Session %s closed because of %s", session.getId(), status.getReason()));
        sessions.remove(session.getId());
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        log.info("Connected ... " + session.getId());
        sessions.put(session.getId(), session);
    }


    @Override
    protected void handleTextMessage(WebSocketSession webSocketSession, TextMessage message) throws Exception {
        var clientMessage = message.getPayload();
        ObjectMapper mapper = new ObjectMapper();
        Request com = mapper.readValue(clientMessage, Request.class);

     try {
            JSch jsch = new JSch();
            Session session = jsch.getSession(com.getUsername(), com.getHost(), com.getPort());

            session.setConfig("StrictHostKeyChecking", "no");
            session.setPassword(com.getPassword());
            session.connect();

            ChannelExec channelExec = (ChannelExec) session.openChannel("exec");
            channelExec.setOutputStream(System.out, true);
            OutputStream outputStreamStdErr = new ByteArrayOutputStream();
            channelExec.setErrStream(outputStreamStdErr, true);

            InputStream in = channelExec.getInputStream();
            channelExec.setCommand(com.getCommand());

            channelExec.connect();

            BufferedReader reader = new BufferedReader(new InputStreamReader(in));
            String line;
            if (!com.getSessionUser().isEmpty()) {
                TextMessage textMessage1 = new TextMessage("-> " + com.getSessionUser() + "$ " + com.getCommand());
                webSocketSession.sendMessage(textMessage1);
            }
                try (ByteArrayInputStream inErr = new ByteArrayInputStream(channelExec.getErrStream().readAllBytes())) {
                    String inErrContent = new String(inErr.readAllBytes());
                    if(!inErrContent.isEmpty()){
                        TextMessage textMessage2 = new TextMessage( inErrContent);
                        webSocketSession.sendMessage(textMessage2);
                    }
                }

            while ((line = reader.readLine()) != null) {
                TextMessage textMessage = new TextMessage(line);
                webSocketSession.sendMessage(textMessage);
            }

            channelExec.disconnect();
            session.disconnect();

        } catch (Exception e) {
            log.error("Error happened: " + e);
            e.printStackTrace();
        }
    }
}
```

The interesting part is `handleTextMessage()` method. As we can see there we get the TextMessage object and map it to the Request model class. 
Then we establish a connection with remote server, and send message with command to the remote machine into the output stream. After that we read the response from the input stream, wrap it to TextMessage object and send as Websocket message to the client. That's it.


Ok, now we have ready backend that is able to receive and handle Websocket messages. It's time to build some simple client.


### Websocket client

We will not be creating a full fledged UI instead let's create a small html page in `resources/templates` directory of our project. We'll name it `main.html`
As a template I took Bootstrap 5 starter template (https://getbootstrap.com/docs/5.3/examples/starter-template/) but you can use any others you prefer most.


But wait, since we are going to add an html template we should add a controller to our backend to render that web page.
Let's do that right away:

```java
package io.kriffer.webterminal.controllers;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class MainController {

    @GetMapping("/")
    public String getMainPage(){
        return "main";
    }
}
```


Alright, now we are able to process get requests on the path "/" and return main.html page. 

Let's go further.

Here is the fragment from the html template that contains the form we use for connection data, terminal window, and input field for commands.

```html
   <form name="connection">

            <div class="row mb-3">
                <label for="host" class="col-sm-1 col-form-label col-form-label-sm">Host</label>
                <div class="col-sm-4">
                    <input type="text" class="form-control form-control-sm" id="host" required>
                </div>
            </div>
            <div class="row mb-3">
                <label for="port" class="col-sm-1 col-form-label col-form-label-sm">Port</label>
                <div class="col-sm-4">
                    <input type="text" class="form-control form-control-sm" id="port" required>
                </div>
            </div>
            <div class="row mb-3">
                <label for="username" class="col-sm-1 col-form-label col-form-label-sm">Username</label>
                <div class="col-sm-4">
                    <input type="text" class="form-control form-control-sm" id="username" required>
                </div>

            </div>
            <div class="row mb-3">
                <label for="password" class="col-sm-1 col-form-label col-form-label-sm">Password</label>
                <div class="col-sm-4">
                    <input type="password" class="form-control form-control-sm" id="password" required>
                </div>

            </div>
            <br/>
            <button type="submit" class="btn btn-primary btn-sm">Open session</button>
            <button type="button" class="btn  btn-sm" id="close-session">Close session</button>
        </form>

        <div class="mb-5">
            <button class="btn btn-secondary btn-sm" style="float:right;" id="clear">Clear</button>
            <textarea class="form-control" id="terminal"></textarea>

            <div class="input-group mb-3">
                <span class="input-group-text" id="user-host"></span>
                <input type="text" class="form-control" id="input-command"
                       placeholder="Type here and press Enter..."></input>

            </div>
        </div>

```

Obviously, we need some JS script process the events coming from the form and fields.

Here is the JS script, that should be put in `resorces/static/js` directory

```js
let socket = new WebSocket(location.protocol !== 'https:' ?
    `ws://${window.location.hostname}:8080/console` :
    `wss://${window.location.hostname}/apps/webterminal/console`);

const commandInput = document.getElementById('input-command');
const host = document.getElementById('host');
const port = document.getElementById('port');
const username = document.getElementById('username');
const password = document.getElementById('password');
const terminal = document.getElementById('terminal');
const span = document.getElementById('user-host');
const closeButton = document.getElementById('close-session');
const clear = document.getElementById('clear');

let request = {};


document.forms.connection.onsubmit = function () {
    request.sessionUser = '';
    request.host = host.value;
    request.port = port.value;
    request.username = username.value;
    request.password = password.value;
    request.command = 'echo ${USER}@${HOSTNAME}';
    socket.send(JSON.stringify(request));
    return false;
};
socket.addEventListener('open', function (event) {
    terminal.value += '🤝 Connection opened, enter session details and click Open session. \r\n';
});

commandInput.addEventListener('keypress', function (event) {

        if (event.key === "Enter") {
            event.preventDefault();
            request.command = this.value;
            socket.send(JSON.stringify(request));
            this.value = '';

        }
    }
)

socket.addEventListener('message', function (event) {

    if (event.data.startsWith(`${username.value}@`)) {
        span.textContent = event.data + ' $';
        request.sessionUser = event.data;
        terminal.value += 'Session opened -> ' + event.data + '\r\n';
        commandInput.focus();
        return;
    }

    terminal.value += event.data + '\r\n';
    terminal.scrollTop = terminal.scrollHeight;

});

clear.addEventListener('click', function (event) {
    event.preventDefault();
    terminal.value = '';
})
closeButton.addEventListener('click', function (event) {
    event.preventDefault();
    socket.close();
})

socket.addEventListener('close', function (event) {
    terminal.value += '⚡ Connection closed, reload page to resume session. \r\n';
    host.value = '';
    port.value = '';
    username.value = '';
    password.value = '';
});

```

The most important parts are around WebSocket object and its methods. As we can see we create and initialize a WebSocket object that allows automatically initiate a connection with server.
After that we manipulate with the method `socket.send()` and add listener to the socket instance to handle incoming response from the server.


That's it! Hopefully someone will find this useful. 


The full project demo is here: https://www.kriffer.io/apps/webterminal/

The source code is here: https://github.com/kriffer/web-terminal














