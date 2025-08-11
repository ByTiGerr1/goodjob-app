# goodjob-app
Este es el repositorio de la app Good Job, proyecto hecho para Proyecto de Software 2025

    ## Para trabajar en otras ramas hacer lo siguiente
    1. Primero se trae el repositorio con "git clone https://github.com/ByTiGerr1/goodjob-app.git", eso traera main.
    2. Se hace "git fetch origin dev" para traer la rama dev.
    3. Se hace "git checkout dev" para cambiar finalmente a la rama dev.
    4. En caso de querer subir el trabajo, luego de hacer los commits necesarios, hacer "git fetch origin" para bajar los cambios de las ramas en Github, luego hacer "git rebase origin/dev" para poner los commits encima de los cambios hechos por otras personas, en caso de haber conflictos arreglarlos. Finalmente, ocupar "git push origin dev --force-with-lease" para subir los commits hechos, esto subirá los cambios solamente si está todo al día en el repositorio local.