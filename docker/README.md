# Docker Deployment Instructions
1. Install Docker
2. Install Docker Compose
2. Install Python
3. Install Jinja2 Python package
```bash
pip install jinja2
```
4. Add the following line to your `hosts` file
```
9.220.207.158   med-p3-dev-cwb.softlayer.com
```
5. Add `med-p3-dev-cwb.softlayer.com:5000` as an insecure registry in your Docker daemon configuration.
6. Authenticate with BSO at `https://byfw.sby.dst.ibm.com:9443/netaccess/loginuser.html`
7. Clone the latest CI scripts from Gitlab
```bash
git clone git@sbygz050202.sby.dst.ibm.com:wh-medtronic-p3/ci.git
```
8. Navigate to the docker controller script directory in a terminal
```bash
cd ci/docker
```
9. Run the controller script
```bash
./controller.py deploy -e <properties_file> -i <image_tag>
```
> **Note:** See `properties/environment/med-p3-ci.json` for an example of a valid properties file

Image tag should be formatted as such:

`med-p3-dev-cwb.softlayer.com:5000/medp3/<component>:<version>`

Where **component** is the name of the Sugar.IQ component to deploy, and **version** is the desired tag. An index of valid image names can be found in the Docker registry UI located [**here**](http://med-p3-dev-cwb.softlayer.com:3000/namespaces/5).
