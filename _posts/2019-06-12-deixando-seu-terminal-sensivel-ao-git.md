---
layout: post
title:  "Deixando seu terminal sensivel ao GIT"
date:   2019-06-12 07:41:10 -0300
categories: pt
---

# Introdução

If you landed on this page and have no clue on what's written here, it's basically a translation of the [original tutorial](https://git-scm.com/book/en/v2/Appendix-A%3A-Git-in-Other-Environments-Git-in-Bash).

O GIT é uma ferramenta para se realizar controle de versão de cádigo fonte que substituiu o SVN (pelo menos na maioria dos projetos mais atuais). Pela facilidade que se tem de criar repositórios no github.com/gitlab.com as vezes nos deparamos com diversos repositorios GIT em nossas máquinas, e para cada repositórios temos a necessidade de saber qual branch estamos e se existem alterações na determinada branch.

Esse tutorial ensina como deixar seu bash mais amigável para repositórios GIT. Me fundamentei em um [tutorial em inglês](https://git-scm.com/book/en/v2/Appendix-A%3A-Git-in-Other-Environments-Git-in-Bash) para escrever este em português.

# Passos

O tutorial é bem simples:
- baixe o arquivo `git-prompt.sh` [do repositório oficial](https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh)
- abra o arquivo `.bashrc`, ou `.bash_profile`, dependendo da sua instalação. Atualmente uso o Debian e o meu `.bashrc` está em $HOME/.bashrc;
- encontre a linha que contenha "force_color_prompt=yes" e a deixe descomentada;
- encontre a linha que contenha "if [ "$color_prompt" = yes ]; then"
  - na linha abaixo, escreva o comando `source /caminho/do/arquivo/git-prompt.sh`
- adicione a variável criada pelo git-prompt.sh: `$(__git_ps1 "\[\033[31m\](%s)")\[\033[00m\] \$ '`
- salve e feche o arquivo
- digite o comando: `source $HOME/.bashrc` e pronto!

Obrigado pela sua atenção. Qualquer dúvida, me mande um email!

Chaws
