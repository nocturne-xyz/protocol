#!/usr/bin/env bash
set -u

# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 
ROOT_DIR="$SCRIPT_DIR/../"
cd "$ROOT_DIR"
 
#!/usr/bin/env bash
if [[ $OSTYPE == 'darwin'* ]]; then
	echo "macOS detected..."

	echo "checking if homebrew is installed..."
	BREW_VERSION=$(brew --version | head -n 1)
	if [ $? -eq 0 ]
	then
		echo "found brew version $BREW_VERSION"
		echo ""
	else
		echo "homebrew not found. installing..."
		curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
		source ~/.bashrc
		BREW_VERSION=$(brew --version | head -n 1)
		echo "installed brew version $BREW_VERSION"
	fi

	echo "checking if gsed is installed..."
	GSED_VERSION=$(gsed --version | head -n 1)
	if [ $? -eq 0 ]
	then
		echo "found gsed version $GSED_VERSION"
		echo ""
	else
		echo "gsed not found. installing..."
		brew install gnu-sed
		source ~/.bashrc
		GSED_VERSION=$(gsed --version | head -n 1)
		echo "installed gsed version $GSED_VERSION"
	fi

	echo "checking if sha256sum is installed..."
	SHA256SUM_VERSION=$(sha256sum --version | head -n 1)
	if [ -n "$SHA256SUM_VERSION" ]
	then
		echo "found sha256sum version $SHA256SUM_VERSION"
		echo ""
	else
		echo "sha256sum not found. installing..."
		brew install coreutils
		echo 'source /usr/local/opt/coreutils/libexec/gnubin' >> ~/.bashrc
		source ~/.bashrc
		SHA256SUM_VERSION=$(sha256sum --version | head -n 1)
		echo "installed sha256sum version $SHA256SUM_VERSION"
	fi
fi
