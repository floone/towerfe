FROM ruby:2.3.1-onbuild
ARG GIT_CLONE_URL="ssh://githost/repo.git"
RUN mkdir ~/.ssh && \
    cp /usr/src/app/ssh/* ~/.ssh/ && \
    echo "StrictHostKeyChecking=no" >> ~/.ssh/config && \
    chmod 600 ~/.ssh/* && \
    rm -rf /usr/src/app/ssh && \
    rm -rf /usr/src/app/git && \
    mkdir /usr/src/app/git && \
    git clone "$GIT_CLONE_URL" /usr/src/app/git/workingcopy
CMD ["./towerfe.rb"]
