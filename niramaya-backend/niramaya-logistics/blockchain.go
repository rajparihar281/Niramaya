package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"log"
	"math/big"
	"os"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// emergencyAuditABI matches EmergencyAudit.sol → logDispatch(string,string,string)
const emergencyAuditABI = `[{"inputs":[{"internalType":"string","name":"_pId","type":"string"},{"internalType":"string","name":"_hId","type":"string"},{"internalType":"string","name":"_dept","type":"string"}],"name":"logDispatch","outputs":[],"stateMutability":"nonpayable","type":"function"}]`

// logDispatchOnChain sends a logDispatch tx and blocks until it is mined.
// Returns the tx hash string, or an error. Non-fatal: caller logs and continues.
func logDispatchOnChain(patientHash, hospitalID, department string) (string, error) {
	rpcURL := os.Getenv("BLOCKCHAIN_RPC_URL")
	contractAddr := os.Getenv("CONTRACT_ADDRESS")
	privKeyHex := os.Getenv("BLOCKCHAIN_PRIVATE_KEY")

	if rpcURL == "" || contractAddr == "" || privKeyHex == "" {
		return "", fmt.Errorf("blockchain env vars not set (BLOCKCHAIN_RPC_URL / CONTRACT_ADDRESS / BLOCKCHAIN_PRIVATE_KEY)")
	}

	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		return "", fmt.Errorf("ethclient dial: %w", err)
	}
	defer client.Close()

	privKey, err := crypto.HexToECDSA(strings.TrimPrefix(privKeyHex, "0x"))
	if err != nil {
		return "", fmt.Errorf("invalid private key: %w", err)
	}

	pubKey := privKey.Public().(*ecdsa.PublicKey)
	fromAddr := crypto.PubkeyToAddress(*pubKey)

	chainID, err := client.ChainID(context.Background())
	if err != nil {
		return "", fmt.Errorf("chainID: %w", err)
	}

	nonce, err := client.PendingNonceAt(context.Background(), fromAddr)
	if err != nil {
		return "", fmt.Errorf("nonce: %w", err)
	}

	gasPrice, err := client.SuggestGasPrice(context.Background())
	if err != nil {
		return "", fmt.Errorf("gasPrice: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(emergencyAuditABI))
	if err != nil {
		return "", fmt.Errorf("abi parse: %w", err)
	}

	data, err := parsedABI.Pack("logDispatch", patientHash, hospitalID, department)
	if err != nil {
		return "", fmt.Errorf("abi pack: %w", err)
	}

	to := common.HexToAddress(contractAddr)

	// Estimate gas dynamically so string storage never hits a hardcoded cap.
	// Add 20% buffer on top of the estimate; fall back to 500000 if estimate fails.
	estimatedGas, err := client.EstimateGas(context.Background(), ethereum.CallMsg{
		From: fromAddr,
		To:   &to,
		Data: data,
	})
	if err != nil {
		log.Printf("⚠ [blockchain] gas estimate failed (%v), using fallback 500000", err)
		estimatedGas = 500000
	}
	gasLimit := estimatedGas * 12 / 10 // +20%

	tx := types.NewTransaction(nonce, to, big.NewInt(0), gasLimit, gasPrice, data)

	signer := types.NewLondonSigner(chainID)
	signedTx, err := types.SignTx(tx, signer, privKey)
	if err != nil {
		return "", fmt.Errorf("sign tx: %w", err)
	}

	if err := client.SendTransaction(context.Background(), signedTx); err != nil {
		return "", fmt.Errorf("send tx: %w", err)
	}

	log.Printf("⛓ [blockchain] tx sent %s — waiting for mining...", signedTx.Hash().Hex())

	// WaitMined blocks until Hardhat mines the block (auto-mining = instant)
	receipt, err := bind.WaitMined(context.Background(), client, signedTx)
	if err != nil {
		return "", fmt.Errorf("WaitMined: %w", err)
	}

	if receipt.Status == types.ReceiptStatusFailed {
		return "", fmt.Errorf("tx reverted in block %d", receipt.BlockNumber)
	}

	log.Printf("✅ [blockchain] mined in block %d tx=%s", receipt.BlockNumber, signedTx.Hash().Hex())
	return signedTx.Hash().Hex(), nil
}
