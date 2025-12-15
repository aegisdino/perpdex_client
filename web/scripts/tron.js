const decimals = 6;
const usdtContractAddress = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'; // USDT 컨트랙트 주소
// TY1DBj7Ys1bDcK37kwATaQpHxdTCnYrr1f (LAYER1)

async function getTRC20Balance(address, contractAddress) {
	try {
		if (!window.tronWeb) {
			throw new Error('TronWeb is not available');
		}

		const contract = await window.tronWeb.contract().at(contractAddress || usdtContractAddress);

		// balanceOf 함수 호출
		const balance = await contract.balanceOf(address).call();

		// TRC20 토큰은 보통 6자리 소수점이므로 이를 반영
		const value = window.tronWeb.toDecimal(balance) / Math.pow(10, decimals);
		return value;
	} catch (error) {
		console.error('getTRC20Balance error:', error);
		return null;
	}
}

async function transferTRC20(toAddress, amount, contractAddress) {
	try {
		if (!window.tronWeb) {
			throw new Error('TronWeb is not available');
		}

		// 컨트랙트 인스턴스 생성
		const contract = await window.tronWeb.contract().at(contractAddress || usdtContractAddress);

		// 전송할 양을 decimals에 맞게 변환 (USDT는 6자리)
		const transferAmount = amount * Math.pow(10, decimals);

		// transfer 함수 호출
		const result = await contract.transfer(
			toAddress,
			window.tronWeb.toHex(transferAmount)
		).send({
			feeLimit: 100000000,
			shouldPollResponse: false // 트랜잭션 즉시 반환
		});

		console.log('Transfer result:', result);
		return result; // 트랜잭션 ID 반환
	} catch (error) {
		console.error('transferTRC20 error:', error);
		throw error;
	}
}

window.getTRC20Balance = getTRC20Balance;
window.transferTRC20 = transferTRC20;
