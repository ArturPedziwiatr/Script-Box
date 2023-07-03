#!/usr/bin/env node

BRed='\033[1;31m'
BGreen='\033[1;92m'
BBlue='\033[1;34m'

Type=''
Form='latest'
NewVersion=""

Dev=false
Master=false
Backup=false

argParser () {
  for arg in $*
  do
    case $arg in
      "-d" | "--dev")
        Dev=true
        ;;

      "-m" | "--master")
        Master=true
        ;;

      "-b" | "--backup")
        Backup=true
        ;;
    esac
  done
}

argGuard () {
  if $Dev && $Master ; then
    echo -e "${BRed} -d && -m cannot be together"
    exit 0
  fi
}

updateVersion () {
  echo -e "${BBlue} Update version (stage 1/3)"

  Version="$(node -pe "require('./package.json').version")"
  number=$(echo $Version | tr "." "\n")
  i=0

  for num in $number
  do
    if [ $i -eq 0 ]; then
      First=$(($num))
    elif [ $i -eq 1 ]; then
      Second=$(($num))
    elif [ $i -eq 2 ]; then
      Last=$(($num))
    fi
    i=$(($i+1))
  done
  
  if [ $Last \< 9 ]
  then 
    Last=$(($Last+1))
  else
    Last=0
    if [ $Second \< 9 ]
    then 
      Second=$(($Second+1))
    else
      Second=0
      First=$(($First+1))
    fi
  fi

  NewVersion="${First}.${Second}.${Last}"
  Form=$NewVersion
  sed -i -e "s/${Version}/${NewVersion}/" ./package.json
}

checkingMode () {
  echo -e "${BBlue} Checking branch (stage 2/3)"

  Branch="$(git rev-parse --abbrev-ref HEAD)"
  if $Dev ; then
    if [ $Branch != "dev" ]; then
      git checkout dev
    fi
    Type="/dev"
  fi

  if $Master ; then
    if [ $Branch != "master" ]; then
      git checkout master
    fi
    updateVersion
    Type="/master"
  fi
}

backup () {
  Name="$(node -pe "require('./package.json').name")"

  if $Backup ; then
    echo -e "${BGreen}Creating docker backup"
    if [ -d "../backup/$(date +%d-%m-%Y)$Type" ]; then
      echo -e "${BGreen}Removing last backup docker img"
      rm ../backup/$(date +%d-%m-%Y)$Type/$Name.tar
    else
      echo -e "${BGreen}Creating a folder for backup docker img"
      mkdir -p ../backup/$(date +%d-%m-%Y)$Type
    fi
    cp -R ./docker$Type/* ../backup/$(date +%d-%m-%Y)$Type/
  fi
}

docker () {
  echo -e "${BBlue} Generate docker img (stage 3/3)"
  if [ -d "./docker$Type" ]; then
    echo -e "${BGreen}Removing last docker img"
    docker compose down
    docker volume rm nuxt_data_src
    rm -r ./docker$Type/
  else
    echo -e "${BGreen}Creating a folder for docker img"
    mkdir -p ./docker$Type/
  fi

  # echo -e "${BGreen}Building docker img"
  # docker build . -t $Name:$Form
  # echo -e "${BGreen}Saving docker img"
  # docker save -o ./docker$Type/$Name.tar $Name:$Form
}

argParser $*
argGuard
updateVersion
checkingMode 
docker
backup 



