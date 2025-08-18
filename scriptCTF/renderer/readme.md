# renderer

```
 Renderer
196

NoobMaster

Introducing Renderer! A free-to-use app to render your images!
Attachments

    chall.zip

Instance Info
Remaining Time: 3542s

nc play.scriptsorcerers.xyz 10426
```


I went to http://play.scriptsorcerers.xyz:10426/


There's a simple page where you can browse files on your machine and upload them, they enforce file types on that upload check otherwise it redirects.

I looked at the `app.py` and there's a url path `/developer` but simply going there you get `You are not a developer!` but it looks like if you have the right cookie `developer_secret_cookie` you can auth as a dev. It looks like you have to try to get that cookie somehow and that its at `/static/uploads/secrets/secret_cookie.txt`


When you do render a file the path looks like http://play.scriptsorcerers.xyz:10426/render/56fd59e2cd36dfcfeb5bfeb7cea1de7d6acc2f36a83df360f48394d48e475d53.png

I tried poking at this path and added `secrets/secret_cookie.txt` and the renderer showed me the developer cookie where it would usually render the image `a0dd893eead8bfc97adb3cc6cf93ae5f93f2c955188dd57373f10ce868a540ac`, after adding that in my developer tools the \developer path authenticated.

Welcome! There is currently 1 unread message: scriptCTF{my_c00k135_4r3_n0t_s4f3!_5eb0d6e71a0f} 

# Flag
`scriptCTF{my_c00k135_4r3_n0t_s4f3!_5eb0d6e71a0f}`
