import React, { useState, useEffect } from "react";
import Caver from "caver-js";
import { useDispatch, useSelector } from "react-redux";
import { setCurrentWeapon } from "../tooltip/TooltipSlice";
import Tooltip from "../tooltip/Tooltip";

import { WeaponContainer } from "../../styles/Weapon.styled";

import { convertDNA } from "../../helper/convertDNA";

import {
  tokenAddress,
  nftAddress,
  nftABI,
} from "../marketplace/nftContractInfo";

import {
  failNoti,
  successNoti,
  clearState,
  pendingNoti,
} from "../notification/notifiactionSlice";

const WeaponRenderer = ({ dna, lvl, durability, id }) => {
  const [weaponInfo, setWeaponInfo] = useState({});
  const dispatch = useDispatch();
  const [isVisible, setIsVisible] = useState(false);
  const [tooltipPos, setTooltipPos] = useState({ x: 0, y: 0 });
  const { address } = useSelector((state) => state.userInfo);

  const repairWeapon = async (e) => {
    e.preventDefault();
    dispatch(pendingNoti());
    if (durability < 10) {
      const caver = new Caver(window.klaytn);

      const kip7 = new caver.klay.KIP7(tokenAddress);
      const allowed = await kip7.allowance(address, nftAddress);

      if (allowed.toString() === "0") {
        try {
          await kip7.approve(nftAddress, caver.utils.toPeb("100000000"), {
            from: address,
          });
        } catch (err) {
          dispatch(failNoti());
        }
      }

      const nft = new caver.klay.Contract(nftABI, nftAddress);
      try {
        await nft.methods
          .fixWeaponDurability(id)
          .send({ from: address, gas: 5000000 });
        dispatch(successNoti({ msg: `NFT 수리 성공!` }));
      } catch (error) {
        dispatch(failNoti());
      }
      setTimeout(() => {
        dispatch(clearState());
      }, 5000);
    }
  };

  useEffect(() => {
    if (dna && lvl && durability)
      setWeaponInfo({ ...convertDNA(dna, lvl, durability) });
  }, [dna]);

  return (
    <>
      {dna && lvl ? (
        <WeaponContainer
          onMouseOver={() => {
            dispatch(setCurrentWeapon({ weapon: weaponInfo }));
            setIsVisible(true);
          }}
          onMouseOut={() => setIsVisible(false)}
          onMouseMove={(e) => {
            setTooltipPos({ x: e.clientX + 20, y: e.clientY + 10 });
          }}
          onClick={repairWeapon}
          durability={durability}
        >
          <img src={weaponInfo.img}></img>
        </WeaponContainer>
      ) : (
        <div
          style={{
            width: "96px",
            height: "96px",

            backgroundColor: "#8f5765",
            border: "5px solid black",
          }}
        ></div>
      )}

      {isVisible && <Tooltip {...tooltipPos}></Tooltip>}
    </>
  );
};

export default WeaponRenderer;
