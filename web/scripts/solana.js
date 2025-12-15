if (typeof window.Buffer === 'undefined') {
  window.Buffer = buffer.Buffer;
}

async function createTransferTransaction(fromAddress, toAddress, lamports, needSerialize) {
  try {
    const { PublicKey, SystemProgram, Transaction, Connection } = solanaWeb3;

    console.log(`createTransferTransaction: fromAddress=${fromAddress}, toAddress=${toAddress}, lamports=${lamports}`);

    const connection = new Connection('https://api.devnet.solana.com');

    // 최근 블록해시 가져오기
    const { blockhash } = await connection.getLatestBlockhash('confirmed');

    const transaction = new Transaction({
      feePayer: new PublicKey(fromAddress),
      recentBlockhash: blockhash,
    }).add(
      SystemProgram.transfer({
        fromPubkey: new PublicKey(fromAddress),
        toPubkey: new PublicKey(toAddress),
        lamports: lamports,
      })
    );

    if (needSerialize)
      return Array.from(transaction.serialize({
        requireAllSignatures: false,
        verifySignatures: false
      }));
    else
      return transaction;
  } catch (error) {
    console.error('Error creating transaction:', error);
    throw error;
  }
}

// 전역 함수로 등록
window.createTransferTransaction = createTransferTransaction;

async function getPhantomBalance(pubkey) {
  try {
    const { Connection, PublicKey } = solanaWeb3;

    // Connection 객체 생성
    const connection = new Connection('https://api.devnet.solana.com');

    const publicKey = new PublicKey(pubkey);

    // 잔액 조회 (lamports 단위로 반환)
    const balance = await connection.getBalance(publicKey, 'finalized');

    console.log('Balance in lamports:', balance);
    return balance;
  } catch (error) {
    console.error('Error getting balance:', error, pubkey);
    throw error;
  }
}

window.getPhantomBalance = getPhantomBalance;
