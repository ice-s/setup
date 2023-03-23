## TEST

Build docker (cpu architecture arm)

Image test - Amazon Linux Arm (AWS))

```shell
docker-compose up -d --build
```

Exec docker run script

```shell
docker exec -it  -u root amazonlinux-arm-test bash
```

```
#cd install
#chmod +x install
#./install.sh
```