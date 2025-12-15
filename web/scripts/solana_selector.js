/**
 * Solana Wallet Selector (Phantom & Solflare)
 */

(function () {
	'use strict';

	let currentWallet = null;
	let currentPublicKey = null;
	let currentWalletType = null; // 'phantom' or 'solflare'

	const WALLET_TYPES = {
		PHANTOM: 'phantom',
		SOLFLARE: 'solflare'
	};

	// 지갑 감지
	function detectWallets() {
		const wallets = {
			phantom: {
				id: WALLET_TYPES.PHANTOM,
				name: 'Phantom',
				available: !!(window.phantom?.solana?.isPhantom),
				provider: window.phantom?.solana
			},
			solflare: {
				id: WALLET_TYPES.SOLFLARE,
				name: 'Solflare',
				available: !!(window.solflare?.isSolflare),
				provider: window.solflare
			}
		};

		console.log('[Solana Selector] Detected wallets:', wallets);
		return wallets;
	}

	// 지갑 연결
	async function connectWallet(walletType) {
		try {
			console.log(`[Solana Selector] Connecting to ${walletType}...`);

			const wallets = detectWallets();
			const wallet = wallets[walletType];

			if (!wallet || !wallet.available) {
				throw new Error(`${walletType} wallet is not available`);
			}

			const provider = wallet.provider;

			// 연결 요청
			const response = await provider.connect();

			currentWallet = provider;
			currentPublicKey = response.publicKey.toString();
			currentWalletType = walletType;

			console.log(`[Solana Selector] Connected to ${walletType}:`, currentPublicKey);

			// 계정 변경 이벤트 리스너 등록
			provider.on('accountChanged', (publicKey) => {
				if (publicKey) {
					currentPublicKey = publicKey.toString();
					console.log('[Solana Selector] Account changed:', currentPublicKey);
				} else {
					// 연결 해제됨
					currentWallet = null;
					currentPublicKey = null;
					currentWalletType = null;
					console.log('[Solana Selector] Wallet disconnected');
				}
			});

			// 연결 해제 이벤트 리스너
			provider.on('disconnect', () => {
				currentWallet = null;
				currentPublicKey = null;
				currentWalletType = null;
				console.log('[Solana Selector] Wallet disconnected');
			});

			return {
				success: true,
				publicKey: currentPublicKey,
				walletType: walletType
			};
		} catch (error) {
			console.error('[Solana Selector] Connection error:', error);
			return {
				success: false,
				error: error.message
			};
		}
	}

	// 지갑 연결 해제
	async function disconnectWallet() {
		try {
			if (currentWallet) {
				await currentWallet.disconnect();
				currentWallet = null;
				currentPublicKey = null;
				currentWalletType = null;
				console.log('[Solana Selector] Disconnected');
			}
			return { success: true };
		} catch (error) {
			console.error('[Solana Selector] Disconnect error:', error);
			return { success: false, error: error.message };
		}
	}

	// 현재 연결된 계정 정보
	function getAccount() {
		return {
			success: true,
			connected: !!currentPublicKey,
			publicKey: currentPublicKey,
			walletType: currentWalletType
		};
	}

	// 사용 가능한 지갑 목록
	function getAvailableWallets() {
		try {
			const wallets = detectWallets();
			return {
				success: true,
				wallets: Object.values(wallets)
			};
		} catch (error) {
			console.error('[Solana Selector] Get wallets error:', error);
			return { success: false, error: error.message };
		}
	}

	// 트랜잭션 전송
	async function sendTransaction(transaction) {
		try {
			if (!currentWallet) {
				throw new Error('Wallet not connected');
			}

			console.log('[Solana Selector] Sending transaction...');

			// 트랜잭션 서명 및 전송
			const { signature } = await currentWallet.signAndSendTransaction(transaction);

			console.log('[Solana Selector] Transaction sent:', signature);
			return {
				success: true,
				signature: signature
			};
		} catch (error) {
			console.error('[Solana Selector] Transaction error:', error);
			return {
				success: false,
				error: error.message
			};
		}
	}

	// 트랜잭션 서명 (전송하지 않음)
	async function signTransaction(transaction) {
		try {
			if (!currentWallet) {
				throw new Error('Wallet not connected');
			}

			console.log('[Solana Selector] Signing transaction...');

			const signedTransaction = await currentWallet.signTransaction(transaction);

			console.log('[Solana Selector] Transaction signed');
			return {
				success: true,
				signedTransaction: signedTransaction
			};
		} catch (error) {
			console.error('[Solana Selector] Sign transaction error:', error);
			return {
				success: false,
				error: error.message
			};
		}
	}

	// 여러 트랜잭션 서명
	async function signAllTransactions(transactions) {
		try {
			if (!currentWallet) {
				throw new Error('Wallet not connected');
			}

			console.log('[Solana Selector] Signing all transactions...');

			const signedTransactions = await currentWallet.signAllTransactions(transactions);

			console.log('[Solana Selector] All transactions signed');
			return {
				success: true,
				signedTransactions: signedTransactions
			};
		} catch (error) {
			console.error('[Solana Selector] Sign all transactions error:', error);
			return {
				success: false,
				error: error.message
			};
		}
	}

	// 메시지 서명
	async function signMessage(message) {
		try {
			if (!currentWallet) {
				throw new Error('Wallet not connected');
			}

			console.log('[Solana Selector] Signing message...');

			// 메시지를 Uint8Array로 변환
			const encodedMessage = new TextEncoder().encode(message);
			const signedMessage = await currentWallet.signMessage(encodedMessage, 'utf8');

			console.log('[Solana Selector] Message signed');
			return {
				success: true,
				signature: signedMessage.signature,
				publicKey: signedMessage.publicKey
			};
		} catch (error) {
			console.error('[Solana Selector] Sign message error:', error);
			return {
				success: false,
				error: error.message
			};
		}
	}

	// 잔액 조회
	async function getBalance(publicKey) {
		try {
			const { Connection, PublicKey } = solanaWeb3;

			if (!publicKey) {
				publicKey = currentPublicKey;
			}

			if (!publicKey) {
				throw new Error('No public key provided');
			}

			// Connection 객체 생성
			const connection = new Connection('https://api.devnet.solana.com');
			const pubKey = new PublicKey(publicKey);

			// 잔액 조회 (lamports 단위로 반환)
			const balance = await connection.getBalance(pubKey, 'finalized');

			console.log('[Solana Selector] Balance in lamports:', balance);
			return {
				success: true,
				balance: balance
			};
		} catch (error) {
			console.error('[Solana Selector] Get balance error:', error);
			return {
				success: false,
				error: error.message
			};
		}
	}

	// 자동 재연결 시도
	async function tryAutoReconnect() {
		try {
			console.log('[Solana Selector] Trying auto-reconnect...');

			const wallets = detectWallets();

			// Phantom 우선 시도
			if (wallets.phantom.available && wallets.phantom.provider.isConnected) {
				currentWallet = wallets.phantom.provider;
				currentPublicKey = wallets.phantom.provider.publicKey.toString();
				currentWalletType = WALLET_TYPES.PHANTOM;
				console.log('[Solana Selector] Auto-reconnected to Phantom:', currentPublicKey);
				return { success: true, publicKey: currentPublicKey, walletType: WALLET_TYPES.PHANTOM };
			}

			// Solflare 시도
			if (wallets.solflare.available && wallets.solflare.provider.isConnected) {
				currentWallet = wallets.solflare.provider;
				currentPublicKey = wallets.solflare.provider.publicKey.toString();
				currentWalletType = WALLET_TYPES.SOLFLARE;
				console.log('[Solana Selector] Auto-reconnected to Solflare:', currentPublicKey);
				return { success: true, publicKey: currentPublicKey, walletType: WALLET_TYPES.SOLFLARE };
			}

			console.log('[Solana Selector] No previous connection found');
			return { success: false, error: 'No previous connection' };
		} catch (error) {
			console.error('[Solana Selector] Auto-reconnect error:', error);
			return { success: false, error: error.message };
		}
	}

	// Global API
	window.SolanaWalletAPI = {
		connect: connectWallet,
		disconnect: disconnectWallet,
		getAccount: getAccount,
		getAvailableWallets: getAvailableWallets,
		sendTransaction: sendTransaction,
		signTransaction: signTransaction,
		signAllTransactions: signAllTransactions,
		signMessage: signMessage,
		getBalance: getBalance,
		tryAutoReconnect: tryAutoReconnect,
		WALLET_TYPES: WALLET_TYPES
	};

	console.log('[Solana Selector] API ready');

	// 페이지 로드 시 자동 재연결 시도
	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', () => {
			setTimeout(tryAutoReconnect, 500);
		});
	} else {
		setTimeout(tryAutoReconnect, 500);
	}
})();
