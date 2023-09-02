# Laboratorio OKD (Upstream OpenSource version de Red Hat OpenShift Container Platform)

## TLDR

### Tareas Pre-Deploy

***Requerimientos:***

- **Service Princiapl**: En la subscripción donde se despliega la solución debe tener los roles: ```Contributor``` y ```User Access Administrator```
- **Zona DNS Pública**: Asignar un subdominio para el uso del cluster. Es necesario crear la zona pública en un resource group, y delegar a la zona principal si fuera necesario.
- **Storage Account**: Se utiliza para subir la imagen de FedoraCoreOS que se usa para las vms masters y workers.

***Paso a Paso:***

#### Ajustar las variables para definir:

- Resource Group Name: Variable en el archivo Makefile
- Resource Group Location: Variable en el archivo Makefile
- Dominio del cluster: Variable en el archivo template de azure ```templates/okd-lab-baserg.bicep```
- Storage Account Name: Variable en el archivo template de azure ```templates/okd-lab-baserg.bicep```
- Storage Account Blob Container Name: Variable en el archivo template de azure ```templates/okd-lab-baserg.bicep```
- URL OKD Installer: Variable en el archivo Makefile (ver [https://github.com/okd-project/okd/releases](https://github.com/okd-project/okd/releases))
- URL y versión de CoreOS a utilizar: Variable en el archivo Makefile (ver Workarround: ```openshift-install coreos print-stream-json | grep azure```)

#### Crear Resource group base, storage account y zona DNS

``` bash
make deploy-base-resource-group
```

#### Delegar zona dns pública en dominio principal

En nuestro ejemplo, se crea la zona ```okd.synchro.ar```. Debe delegarse a los dns raiz que administran ```synchro.ar```

#### Descargar la imágen adecuada de Fedora CoreOS para la versión a instalar de OKD

``` bash
make get-fcos-image
```

#### Subir el archivo .vhd a la Storage Account, como page blob.

``` bash
make upload-vhd-to-azure
```

Se debe activar el acceso público a la imagen de CoreOS en Azure.

#### Iniciar la instalación, crear archivo ```install-config.yaml```, y personalizar el deploy en Azure.

``` bash
make openshift-create-install-configs
```

El proceso pregunta información que necesita para comunicarse con la infra a desplegar:

- key ssh para agregar a los nodos instalados
- cloud donde desplegar la infra: azure
- datos del Service Principal para conectarse
- región donde desplegar la infra
- dominio base para el cluster, se siguiere el encontrado en la zona DNS
- nombre del cluster para completar el fqdn junto al dominio base
- "secret" para descargar imágenes de operadores de redhat (Opcional)

Una vez completos los datos, se crea el archivo que debe modificarse.

Modificar la plataforma y la imagen de Azure a utilizar en el control plane y los workers

``` yaml
apiVersion: v1
baseDomain: okd.synchro.ar
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    azure:
      type: Standard_B2as_v2
      osDisk:
        diskSizeGB: 256
        diskType: StandardSSD_LRS
  replicas: 2
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    azure:
      type: Standard_B4as_v2
      osDisk:
        diskSizeGB: 256
        diskType: StandardSSD_LRS
  replicas: 3
```

Dejar 3 réplicas para los masters, y 2 réplicas para los workers. Los masters deben tener como mínimo 16GB de RAM, los workers 8GB de RAM

Modificar la definición del plugin de red, utilzamos ```OpenshiftSDN```

``` yaml
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OpenshiftSDN
  serviceNetwork:
  - 172.30.0.0/16
```

#### Iniciar la creación del cluster

``` bash
make openshift-create-cluster
```

Se puede revisar el archivo ```.openshift_install.log``` para seguir el despliegue de la infraestructura

---

## Detalles de la implementación

El objetivo es desplegar una infraestructura típica de OKD en el cloud de Azure, utilizando IaaS (Infraestructura como servicio).

Las fuentes para este laboratorio está en la documentación de OKD: [https://www.okd.io/](https://www.okd.io/)

Y en el repositorio GitHub oficial del producto:  [https://github.com/okd-project/okd](https://github.com/okd-project/okd)

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

- [https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-client-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz](https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-client-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz)
- [https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-install-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz](https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-install-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz)

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

[```https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220327.3.0/x86_64/fedora-coreos-35.20220327.3.0-azure.x86_64.vhd.xz```](https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220327.3.0/x86_64/fedora-coreos-35.20220327.3.0-azure.x86_64.vhd.xz)

Localmente se debe descomprimir la imágen VHD, y luego se debe subir a un storage account, como un blob page, que permita acceso público, para que el instalador pueda acceder a la imagen.
Se indica la URL de la imagen en una variable de entorno antes de ejecutar el instalador de OKD:

```export OPENSHIFT_INSTALL_OS_IMAGE_OVERRIDE=https://<storageaccount>.blob.windows.net/<container>/fedora-coreos-35.20220327.3.0-azure.x86_64.vhd```
