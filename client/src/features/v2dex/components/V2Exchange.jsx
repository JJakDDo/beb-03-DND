import React, { useState, useEffect, useRef } from "react";
import Caver from "caver-js";
import { exchangeABI } from "../../dex/contractInfo";
import { pairABI } from "../../V2Swap/v2Contract";
import {
  LPContainer,
  LPHeader,
  Content,
} from "../../../styles/LPContainer.styled";
import {
  SwapInfoContainer,
  InfoContainer,
} from "../../../styles/TokenSwap.styled";
import { Button } from "../../../styles/Modal.styled";

const V2Exchange = ({
  address,
  name,
  lp,
  tokenAddress1,
  tokenAddress2,
  account,
  setIsWithdrawal,
  setSelectedExchange,
}) => {
  const [reservedKlay, setReservedKlay] = useState(0);
  const [reservedToken, setReservedToken] = useState(0);
  const [reservedTokenA, setReservedTokenA] = useState(0);
  const [reservedTokenB, setReservedTokenB] = useState(0);
  const [tokenAName, setTokenAName] = useState("");
  const [tokenASymbol, setTokenASymbol] = useState("");
  const [tokenBName, setTokenBName] = useState("");
  const [tokenBSymbol, setTokenBSymbol] = useState("");
  const [share, setShare] = useState("");
  const input1 = useRef(null);
  const input2 = useRef(null);
  const removeLp = useRef(null);

  const [showMore, setShowMore] = useState(false);

  useEffect(() => {
    const getReserved = async () => {
      const caver = new Caver(window.klaytn);
      const pair = new caver.klay.Contract(pairABI, address);

      const reserved = await pair.methods.getReserves().call();
      setReservedTokenA(caver.utils.fromPeb(reserved[0]));
      setReservedTokenB(caver.utils.fromPeb(reserved[1]));

      let token = new caver.klay.KIP7(tokenAddress1);
      let name = await token.name();
      let symbol = await token.symbol();

      setTokenAName(name);
      setTokenASymbol(symbol);

      token = new caver.klay.KIP7(tokenAddress2);
      name = await token.name();
      symbol = await token.symbol();

      setTokenBName(name);
      setTokenBSymbol(symbol);

      //getShareOfLP(lp);
    };
    console.log(lp);
    getReserved();
  }, []);

  const getShareOfLP = async (balance) => {
    const caver = new Caver(window.klaytn);

    const kip7 = new caver.klay.KIP7(address);
    const totalSupply = await kip7.totalSupply();
    const lpShare = Number(
      caver.utils.fromPeb(
        caver.utils
          .toBN(caver.utils.toPeb(balance))
          .mul(caver.utils.toBN(Math.pow(10, 18)))
          .div(caver.utils.toBN(totalSupply))
      )
    );
    setShare(parseFloat(Number(lpShare * 100).toFixed(2)));
  };

  return (
    <LPContainer
      height={showMore ? 250 : 50}
      onClick={() => setShowMore(!showMore)}
    >
      <Content>
        <LPHeader scale={showMore ? -1 : 1}>
          <div>
            <h2>{name}</h2>
            <p>{parseFloat(Number(lp).toFixed(6))}</p>
          </div>
          <img src='assets/arrowDown.png'></img>
        </LPHeader>
        <SwapInfoContainer>
          <InfoContainer>
            <span>Pooled {tokenASymbol}</span>
            <span>{parseFloat(Number(reservedTokenA).toFixed(6))}</span>
          </InfoContainer>
          <InfoContainer>
            <span>Pooled {tokenBSymbol}</span>
            <span>{parseFloat(Number(reservedTokenB).toFixed(6))}</span>
          </InfoContainer>
        </SwapInfoContainer>
        <Button
          style={{ bottom: "-100px" }}
          onClick={() => {
            setIsWithdrawal(true);
            setSelectedExchange(address);
          }}
        >
          출금
        </Button>
      </Content>
    </LPContainer>
  );
};

export default V2Exchange;
