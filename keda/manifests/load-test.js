import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 400 }, // ramp up to 400 users
    { duration: '1m', target: 400 }, // stay at 400 for ~4 hours
    { duration: '30s', target: 0 }, // scale down. (optional)
  ],
};

const ITERATIONS = 100000;  // Fixed number of iterations for consistency

export default function () {
  const url = `http://${__ENV.MY_HOSTNAME}/simulate?iterations=${ITERATIONS}`;
  http.get(url);
  sleep(1);
}