FROM akqf/root-python3

ADD . /root-recipes
WORKDIR /root-recipes

RUN pacman -S make --noconfirm
RUN pip install -r requirements.txt
