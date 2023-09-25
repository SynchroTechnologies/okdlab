# Laboratorio OCP (Red Hat OpenShift Container Platform) en Azure usando IaaS

## Paso a Paso abreviado

### Tareas Pre-Deploy

***Requerimientos:***

- **Service Princiapl**: En la subscripción donde se despliega la solución debe tener los roles: ```Contributor``` y ```User Access Administrator```
- **Zona DNS Pública**: Asignar un subdominio para el uso del cluster. Es necesario crear la zona pública en un resource group, y delegar a la zona principal si fuera necesario.

***Paso a Paso:***

#### Ajustar las variables para definir:

- Resource Group Name: Variable en el archivo Makefile
- Resource Group Location: Variable en el archivo Makefile
- Dominio del cluster: Variable en el archivo Makefile
- Storage Account Name: Variable en el archivo Makefile
- Storage Account Blob Container Name: Variable en el archivo Makefile
- URL OCP Installer: Variable en el archivo Makefile (ver [https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/))

#### Crear Resource group base, storage account y zona DNS

``` bash
make deploy-base-resource-group
```

#### Delegar zona dns pública en dominio principal

En nuestro ejemplo, se crea la zona ```ocplab.ha.ar```. Debe delegarse a los dns raiz que administran ```ha.ar```

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
baseDomain: ocplab.ha.ar
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


#### Iniciar la creación del cluster

``` bash
make openshift-create-cluster
```

Se puede revisar el archivo ```.openshift_install.log``` para seguir el despliegue de la infraestructura

---

## Detalles de la implementación

El objetivo es desplegar una infraestructura típica de OCP en el cloud de Azure, utilizando IaaS (Infraestructura como servicio).

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

Dentro de una instalación UPI en Azure, OCP espera una serie de templates ARM definidos por el usuario para crear la infraestructura.

***Nota:*** Para evitar un gasto excesivo, se realizará una instalación con customización, para poder editar el tamaño de las VMs, y que tengan un costo razonable para un laboratorio.

