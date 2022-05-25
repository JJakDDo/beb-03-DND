import React, { useState, useEffect } from "react";

import Caver from "caver-js";
import { useDispatch, useSelector } from "react-redux";

import { InventoryContainer } from "../../../styles/Inventory.styled";
import WeaponRenderer from "../../weapon/WeaponRenderer";
import { updateList, updateOnSaleList } from "../marketplaceSlice";
import { BuySellButton } from "../../../styles/Inventory.styled";

import {
  pendingNoti,
  successNoti,
  failNoti,
  clearState,
} from "../../notification/notifiactionSlice";

import {
  tokenAddress,
  marketAddress,
  nftAddress,
  marketABI,
  nftABI,
} from "../nftContractInfo";
const caver = new Caver(window.klaytn);

const TradingList = ({ getMarketplaceList }) => {
  const dispatch = useDispatch();
  const { address } = useSelector((state) => state.userInfo);
  const { list } = useSelector((state) => state.marketplace);

  const buyNewNFT = async () => {
    dispatch(pendingNoti());
    const nft = new caver.klay.Contract(nftABI, nftAddress);

    try {
      await nft.methods.mint(address, 1).send({
        from: address,
        gas: 2000000,
      });
      getMarketplaceList();
      dispatch(successNoti({ msg: `NFT 구매 성공!` }));
    } catch (err) {
      dispatch(failNoti());
    }
    setTimeout(() => {
      dispatch(clearState());
    }, 5000);
  };

  const buyWeapon = async (id) => {
    dispatch(pendingNoti());
    const market = new caver.klay.Contract(marketABI, marketAddress);

    const kip7 = new caver.klay.KIP7(tokenAddress);
    const allowed = await kip7.allowance(address, marketAddress);

    if (allowed.toString() === "0") {
      try {
        await kip7.approve(marketAddress, caver.utils.toPeb("100000000"), {
          from: address,
        });
      } catch (err) {
        dispatch(failNoti());
      }
    }
    try {
      await market.methods.buyNft(id).send({ from: address, gas: 5000000 });
      getMarketplaceList();
      dispatch(successNoti({ msg: `NFT 구매 성공!` }));
    } catch (error) {
      dispatch(failNoti());
    }
    setTimeout(() => {
      dispatch(clearState());
    }, 5000);
  };

  return (
    <InventoryContainer style={{ height: "70%" }}>
      <div>
        <img
          src='assets/chest.png'
          style={{
            width: "96px",
            height: "96px",
            backgroundColor: "#8f5765",
            border: "5px solid black",
            marginBottom: "-3px",
          }}
        ></img>
        <BuySellButton onClick={() => buyNewNFT()}>50 URU</BuySellButton>
      </div>
      {list.map((item, idx) => {
        return (
          <div key={idx}>
            <WeaponRenderer {...item} />
            <BuySellButton onClick={() => buyWeapon(item.marketId)}>
              {parseFloat(Number(caver.utils.fromPeb(item.price)).toFixed(4))}{" "}
              URU
            </BuySellButton>
          </div>
        );
      })}
    </InventoryContainer>
  );
};

export default TradingList;
