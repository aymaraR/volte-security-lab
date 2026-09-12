# Prerequisitos — Docker + WSL2 en Windows

Antes de comenzar con el laboratorio necesitas tener Docker corriendo sobre WSL2. Esta guía asume Windows 10 o Windows 11 de 64 bits.

## 1. Instalar WSL2

Abre PowerShell como Administrador y ejecuta:

```powershell
wsl --install
```

Esto instala WSL2 y Ubuntu automáticamente. Reinicia el PC cuando termine.

Luego verifica que WSL2 quedó activo:

```powershell
wsl --set-default-version 2
wsl --list --verbose
```

Deberías ver Ubuntu listado con la versión 2.

## 2. Instalar Docker Desktop

1. Descarga Docker Desktop desde https://www.docker.com/products/docker-desktop/
2. Ejecuta el instalador `.exe`
3. Durante la instalación Docker detectará WSL2 automáticamente y lo usará como backend
4. Finaliza e inicia Docker Desktop

## 3. Habilitar integración con Ubuntu

Dentro de Docker Desktop ve a:

**Settings → Resources → WSL Integration**

Activa las dos opciones:
- Enable integration with my default WSL distro
- Ubuntu (en la lista de distros adicionales)

Haz clic en **Apply & Restart**.

## 4. Verificar la instalación

Abre Ubuntu desde el menú inicio de Windows. Verás una terminal con este formato:

```
tuusuario@NOMBRE-PC:~$
```

Desde ahí ejecuta:

```bash
docker --version
docker run hello-world
```

Si el segundo comando imprime un mensaje que empieza con `Hello from Docker!`, todo está listo para continuar.

## Nota

A partir de aquí todo el trabajo se hace desde la terminal de Ubuntu, no desde PowerShell. Usa clic derecho para pegar en la terminal de Ubuntu.
