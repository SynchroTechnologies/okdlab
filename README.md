# Laboratorio OKD (Upstream OpenSource version de Red Hat OpenShift Container Platform)

El objetivo es desplegar una infraestructura típica de OKD en el cloud de Azure, utilizando IaaS (Infraestructura como servicio).

Las fuentes para este laboratorio está en la documentación de OKD: https://www.okd.io/

Y en el repositorio GitHub oficial del producto:  https://github.com/okd-project/okd

## Hoja de ruta

- Desplegar OKD en versión 4.10 (no la última), para poder probar los pasos de actualización
- Desplegar los operadores que tiene Andreani, los posibles.
- Realizar la actualización de OKD a la última versión menor de 4.10
- Realizar la actualización de OKD a la rama 4.11
- Realizar la actualización de OKD a la rama 4.12
- Utilizar el laboratorio para realizar pruebas varias del escenario Andreani
- Ganar experiencia en la instalación y administración de OpenShift Cloud Platform

## Pre-Deploy

### Herramientas para la instalación

Se descargan las siguientes herramientas:

- https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-client-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz
- https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-install-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz

La versión 4.10.0-0.okd-2022-05-28 es la última versión de Mayo de 2022. La última version en la rama 4.10 es 4.10.0-0.okd-2022-07-09. Son tres versiones adelantes de la primera instalada.

### Estrategia de instalación

La documentación de Openshift tiene dos estrategias principales: IPI (Installer-provisioned infraestructure), UPI e (User-provisioned infraestructure).

En la estrategia IPI el instalador de OKD se encarga de la provisión de los servidores que ejecutan OKD. En el caso de Azure, el instalador se encarga de crear los recursos:
resource groups, virtual networks, vms, etc...

En la estrategia UPI el usuario provisiona la infraestructura, y el instalador de OKD despliega los ejecutables. En el caso de Azure, implica que el usuario crea los recursos, y le indica
al instalador cómo usarla.

La infraestructura de Andreani fue instalada con la estrategia IPI, sobre la vase de oVirt (Upstream Opensource version de Linux Virtualization). Para simular el ambiente de Andreani
vamos a utilizzar la misma estrategia.

Dentro de una instalación IPI en Azure, OKD ofrece algunas alternativas:

- Quick Install. Es la más automática de las opciones, con muy poca interacción, lo necesario para definir los accesos al cloud de Azure.
- Install with Customization. La instalación se hace en tres pasos, permitiendo customizar algunas definiciones: tamaño de las VMs, plugins de redes, etc.
- Install with Network Customization. En esta opción el instalador permite customizar las opciones de red: crear una vNet, deploy de un cluster privado.

Dentro de una instalación UPI en Azure, OKD espera una serie de templates ARM definidos por el usuario para crear la infraestructura.

***Nota:*** Debido a un problema de provisionamiento en Azure, no se encuentran disponibles las imágenes FCOS (Fedora CoreOS) que son la base de cada VM. Por eso, es necesario realizar
unos pasos manuales para disponibilizar la imagen adecuada para la instalación.

***Nota:*** Para evitar un gasto excesivo, se realizará una instalación con customización, para poder editar el tamaño de las VMs, y que tengan un costo razonable para un laboratorio.

### Workarround para la provisión de una imagen FCOS requerida para la instalación

El objetivo del workarround es proveer al instalador la imagen de FCOS desde una storage account para que pueda generar la imagen de una VM necesaria para el deploy de las VMs de la plataforma.

Se puede verificar la versión de OKD del instalador con el comando:  

```openshift-installer version```

La versión de la imagen necesaria para la versión de OKD que estamos instalando está definida en un archivo json en el código fuente del instalador. Para poder listar las versiones necesarias
para azure se debe usar el siguiente comando:

```openshift-install coreos print-stream-json```

Para la versión 4.10.0-0.okd-2022-05-28-062148 se debe descargar la imagen:

```https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220327.3.0/x86_64/fedora-coreos-35.20220327.3.0-azure.x86_64.vhd.xz```

Localmente se debe descomprimir la imágen VHD, y luego se debe subir a un storage account, como un blob page, que permita acceso público, para que el instalador pueda acceder a la imagen.
Se indica la URL de la imagen en una variable de entorno antes de ejecutar el instalador de OKD:

```export OPENSHIFT_INSTALL_OS_IMAGE_OVERRIDE=https://<storageaccount>.blob.windows.net/<container>/fedora-coreos-35.20220327.3.0-azure.x86_64.vhd```

## Deploy

