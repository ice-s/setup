## TEST

Build docker (cpu architecture arm)

Image test - centos7 arm (google cloud platform) and Amazon Linux Arm (AWS))

```shell
docker-compose up -d --build
```

Exec docker run script

```shell
docker exec -it  -u root centos7-test bash
```

```
#cd install
#chmod +x install
#./install.sh
```