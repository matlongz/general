PS1="\u@\h:\w/
$ "

alias ls='ls -F'

PATH=".:${PATH}"
export PATH

export BASH_SILENCE_DEPRECATION_WARNING=1

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/mdas/google-cloud-sdk/path.bash.inc' ]; then . '/Users/mdas/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/mdas/google-cloud-sdk/completion.bash.inc' ]; then . '/Users/mdas/google-cloud-sdk/completion.bash.inc'; fi

# Setting PATH for Python 3.13
# The original version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.13/bin:${PATH}"
export PATH

# Setting PATH for Python 3.13
# The original version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.13/bin:${PATH}"
export PATH

# Claude Code CLI
export PATH="$HOME/.local/bin:$PATH"
