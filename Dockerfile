FROM akqf/root-python3

ADD . /root-recipes
WORKDIR /root-recipes


# Update the mirror list
RUN pacman -Sy --noconfirm


# Install make
RUN pacman -S make --noconfirm


# install all python requirements
RUN pip install -r requirements.txt
