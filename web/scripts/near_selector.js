/**
 * NEAR Wallet Selector with Modal UI
 */

(function () {
	'use strict';

	let modal = null;
	let selector = null;
	let currentAccountId = null;

	let networkConfig = {
		networkId: 'mainnet',
		contractId: null,
	};

	// 모달 연결 완료를 기다리기 위한 Promise resolver
	let modalConnectionResolver = null;

	function waitForLibrary() {
		return new Promise((resolve) => {
			const check = setInterval(() => {
				if (window.NearWalletSelectorBundle &&
					window.NearWalletSelectorBundle.setupWalletSelector &&
					window.NearWalletSelectorBundle.setupModal) {
					clearInterval(check);
					console.log('[NEAR Selector] Bundle loaded');
					resolve();
				}
			}, 100);
		});
	}

	function configure(config) {
		if (config.networkId) networkConfig.networkId = config.networkId;
		if (config.contractId) networkConfig.contractId = config.contractId;
		console.log('[NEAR Selector] Configured:', networkConfig);
	}

	async function initNearWalletSelector() {
		try {
			console.log('[NEAR Selector] Initializing...');

			await waitForLibrary();

			const bundle = window.NearWalletSelectorBundle;

			// Wallet Selector 초기화
			selector = await bundle.setupWalletSelector({
				network: networkConfig.networkId,
				modules: [
					bundle.setupMeteorWallet(),
					bundle.setupMyNearWallet(),
					bundle.setupHereWallet(),
				],
			});

			// Modal 초기화
			modal = bundle.setupModal(selector, {
				contractId: networkConfig.contractId || 'guest-book.testnet',
			});

			// 계정 변경 감지
			const subscription = selector.store.observable.subscribe((state) => {
				console.log('[NEAR Selector] State update:', state);
				if (state.accounts && state.accounts.length > 0) {
					currentAccountId = state.accounts[0].accountId;
					console.log('[NEAR Selector] Account changed:', currentAccountId);

					// 모달 연결 대기 중이었다면 resolve
					if (modalConnectionResolver) {
						modalConnectionResolver(currentAccountId);
						modalConnectionResolver = null;
					}
				} else {
					currentAccountId = null;
				}
			});

			// 자동 재연결: 이전 세션에서 연결된 지갑이 있는지 확인
			const state = selector.store.getState();
			if (state.accounts && state.accounts.length > 0) {
				currentAccountId = state.accounts[0].accountId;
				console.log('[NEAR Selector] Auto-reconnected:', currentAccountId);
			}

			console.log('[NEAR Selector] Initialized successfully');
			return { success: true };
		} catch (error) {
			console.error('[NEAR Selector] Init error:', error);
			return { success: false, error: error.message };
		}
	}

	async function showModal() {
		try {
			if (!modal) {
				const result = await initNearWalletSelector();
				if (!result.success) {
					throw new Error(result.error);
				}
			}

			console.log('[NEAR Selector] Current state before modal:', selector.store.getState());

			// 연결 완료를 기다리는 Promise 생성
			return new Promise((resolve) => {
				let timeoutId;
				let checkInterval;

				const cleanup = () => {
					if (timeoutId) clearTimeout(timeoutId);
					if (checkInterval) clearInterval(checkInterval);
					modalConnectionResolver = null;
				};

				const checkConnection = () => {
					const state = selector.store.getState();
					console.log('[NEAR Selector] Checking state:', state);

					if (state.accounts && state.accounts.length > 0) {
						const accountId = state.accounts[0].accountId;
						console.log('[NEAR Selector] Connection detected:', accountId);
						cleanup();
						currentAccountId = accountId;
						resolve({
							success: true,
							accountId: accountId
						});
						return true;
					}
					return false;
				};

				// 상태 변화 리스너 등록
				const unsubscribe = selector.store.observable.subscribe((state) => {
					console.log('[NEAR Selector] State changed:', state);
					if (checkConnection()) {
						unsubscribe();
					}
				});

				// 30초 타임아웃
				timeoutId = setTimeout(() => {
					console.log('[NEAR Selector] Connection timeout');
					cleanup();
					unsubscribe();
					resolve({
						success: false,
						error: 'Connection timeout'
					});
				}, 30000);

				// 폴백: 주기적으로 상태 확인
				checkInterval = setInterval(() => {
					if (checkConnection()) {
						unsubscribe();
					}
				}, 500);

				// 모달 표시
				console.log('[NEAR Selector] Showing modal...');
				modal.show();
			});
		} catch (error) {
			console.error('[NEAR Selector] Show modal error:', error);
			return { success: false, error: error.message };
		}
	}

	async function connectWallet(walletId) {
		try {
			console.log(`[NEAR Selector] Connecting ${walletId}...`);

			if (!selector) {
				const result = await initNearWalletSelector();
				if (!result.success) {
					throw new Error(result.error);
				}
			}

			const wallet = await selector.wallet(walletId);
			const accounts = await wallet.signIn({
				contractId: networkConfig.contractId,
			});

			if (accounts && accounts.length > 0) {
				currentAccountId = accounts[0].accountId;
				console.log(`[NEAR Selector] Connected: ${currentAccountId}`);
				return {
					success: true,
					accountId: currentAccountId,
				};
			}

			throw new Error('No accounts returned');
		} catch (error) {
			console.error('[NEAR Selector] Connect error:', error);
			return {
				success: false,
				error: error.message,
			};
		}
	}

	async function disconnectWallet() {
		try {
			if (selector) {
				const wallet = await selector.wallet();
				await wallet.signOut();
				currentAccountId = null;
				console.log('[NEAR Selector] Disconnected');
			}
			return { success: true };
		} catch (error) {
			console.error('[NEAR Selector] Disconnect error:', error);
			return { success: false, error: error.message };
		}
	}

	function getAccount() {
		return {
			success: true,
			connected: !!currentAccountId,
			accountId: currentAccountId,
		};
	}

	async function getAvailableWallets() {
		try {
			if (!selector) {
				const result = await initNearWalletSelector();
				if (!result.success) {
					throw new Error(result.error);
				}
			}

			const wallets = await selector.store.getState().modules;
			return {
				success: true,
				wallets: wallets.map(w => ({
					id: w.id,
					name: w.metadata.name,
					available: w.metadata.available,
				}))
			};
		} catch (error) {
			console.error('[NEAR Selector] Get wallets error:', error);
			return { success: false, error: error.message };
		}
	}

	async function sendTransaction(receiverId, actions) {
		try {
			if (!selector) {
				throw new Error('Wallet not initialized');
			}

			const wallet = await selector.wallet();
			const result = await wallet.signAndSendTransaction({
				receiverId: receiverId,
				actions: actions,
			});

			console.log('[NEAR Selector] Transaction sent:', result);
			return {
				success: true,
				transactionHash: result.transaction.hash,
			};
		} catch (error) {
			console.error('[NEAR Selector] Transaction error:', error);
			return {
				success: false,
				error: error.message,
			};
		}
	}

	async function signMessage(message, recipient, nonce) {
		try {
			if (!selector) {
				throw new Error('Wallet not initialized');
			}

			const wallet = await selector.wallet();

			// NEAR Wallet Selector의 signMessage는 NEP-413 표준을 따름
			// https://github.com/near/NEPs/blob/master/neps/nep-0413.md
			const signedMessage = await wallet.signMessage({
				message: message,
				recipient: recipient || 'perpdex.near', // 메시지 수신자 (컨트랙트 ID)
				nonce: nonce ? Buffer.from(nonce) : Buffer.from(new Uint8Array(32)), // 재사용 방지 nonce
			});

			console.log('[NEAR Selector] Message signed:', signedMessage);

			// signedMessage 구조: { signature, publicKey }
			return {
				success: true,
				signature: signedMessage.signature,
				publicKey: signedMessage.publicKey,
			};
		} catch (error) {
			console.error('[NEAR Selector] Sign message error:', error);
			return {
				success: false,
				error: error.message,
			};
		}
	}

	// Global API
	window.NearWalletAPI = {
		configure: configure,
		init: initNearWalletSelector,
		showModal: showModal,
		getAvailableWallets: getAvailableWallets,
		connect: connectWallet,
		disconnect: disconnectWallet,
		getAccount: getAccount,
		sendTransaction: sendTransaction,
		signMessage: signMessage,
	};

	console.log('[NEAR Selector] Modal API ready');
})();
