import { AptosClient } from "aptos";
import { NODE_URL } from "../constants";

export const aptosClient = new AptosClient(NODE_URL);
