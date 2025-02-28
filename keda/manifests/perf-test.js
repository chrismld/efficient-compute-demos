import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 400 }, // ramp up to 400 users
    { duration: '1m', target: 400 }, // stay at 400 for ~4 hours
    { duration: '30s', target: 0 }, // scale down. (optional)
  ],
};

export default function () {
  http.get('http://ad3392667aef743bf98c6d3aa46d3898-1288783823.eu-west-1.elb.amazonaws.com/monte-carlo-pi?iterations=100000');
  sleep(1);
}