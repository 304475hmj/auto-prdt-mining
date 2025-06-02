const axios = require('axios');
const fs = require('fs').promises;
const chalk = require('chalk');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { ethers } = require('ethers');

// 延迟函数
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// 格式化剩余时间
function formatTimeRemaining(timeMs) {
  if (timeMs <= 0) return '0秒';
  const hours = Math.floor(timeMs / 3600000);
  const minutes = Math.floor((timeMs % 3600000) / 60000);
  const seconds = Math.floor((timeMs % 60000) / 1000);
  let timeString = '';
  if (hours > 0) timeString += hours + '小时 ';
  if (minutes > 0 || hours > 0) timeString += minutes + '分钟 ';
  timeString += seconds + '秒';
  return timeString.trim();
}

// 格式化时间显示（北京时间）
function formatDateTime(date) {
  const beijingDate = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return beijingDate.toISOString().replace('T', ' ').substring(0, 19) + ' (北京时间)';
}

// 显示标题
console.log(chalk.cyan.bold('=== PRDT Finance 自动挖矿签到脚本 ===\n'));

// 加载私钥
async function loadPrivateKeys() {
  try {
    const data = await fs.readFile('keys.txt', 'utf-8');
    const lines = data.split('\n').filter(line => 
      line.trim() !== '' && !line.trim().startsWith('#')
    );
    const wallets = lines.map(privateKey => {
      try {
        const wallet = new ethers.Wallet(privateKey.trim());
        return { address: wallet.address, privateKey: privateKey.trim() };
      } catch (err) {
        console.log(chalk.red(`❌ 无效的私钥: ${privateKey.slice(0, 10)}...`));
        return null;
      }
    }).filter(wallet => wallet !== null);
    console.log(chalk.green(`✅ 已加载 ${wallets.length} 个钱包 📋`));
    return wallets;
  } catch (error) {
    console.log(chalk.red(`❌ 加载私钥出错: ${error.message}`));
    return [];
  }
}

// 加载代理（可选）
async function loadProxies() {
  try {
    const data = await fs.readFile('proxy.txt', 'utf-8');
    const proxies = data.split('\n').filter(line => line.trim() !== '');
    console.log(chalk.green(`✅ 已加载 ${proxies.length} 个代理 🌐`));
    return proxies;
  } catch (error) {
    console.log(chalk.red(`❌ 加载代理出错: ${error.message}`));
    return [];
  }
}

// 创建代理
function createProxyAgent(proxy) {
  if (proxy.startsWith('http://')) {
    return new HttpsProxyAgent(proxy);
  }
  return null; // 可扩展支持其他代理类型
}

// 获取 nonce
async function generateNonce(walletAddress, proxyAgent) {
  try {
    const response = await axios.post(
      'https://api.prdt.finance/wallet/generateNonce', // 假设的 API 端点
      { walletAddress },
      {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/135.0.0.0'
        },
        httpsAgent: proxyAgent
      }
    );
    if (response.data.code === 200) {
      return response.data.result.nonce;
    }
    throw new Error('生成 nonce 失败');
  } catch (error) {
    throw new Error(`获取 nonce 失败: ${error.message}`);
  }
}

// 执行登录
async function performLogin(wallet, proxyAgent, referralCode) {
  try {
    const nonce = await generateNonce(wallet.address, proxyAgent);
    console.log(chalk.yellow(`🔐 正在登录钱包: ${wallet.address}`));
    const walletInstance = new ethers.Wallet(wallet.privateKey);
    const signature = await walletInstance.signMessage(nonce);
    const loginData = {
      address: wallet.address,
      referralCode,
      message: nonce,
      signature
    };
    const response = await axios.post(
      'https://api.prdt.finance/wallet/login', // 假设的 API 端点
      loginData,
      {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/135.0.0.0'
        },
        httpsAgent: proxyAgent
      }
    );
    if (response.data.code === 200) {
      console.log(chalk.green(`✅ 钱包登录成功: ${wallet.address} 🔑`));
      return response.data.result.token;
    }
    throw new Error('登录失败: ' + (response.data.message || '未知错误'));
  } catch (error) {
    throw new Error(`登录失败: ${error.message}`);
  }
}

// 执行挖矿签到
async function performMiningCheckIn(token, proxyAgent) {
  try {
    const response = await axios.post(
      'https://api.prdt.finance/mining/checkIn', // 假设的 API 端点
      {},
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/135.0.0.0'
        },
        httpsAgent: proxyAgent
      }
    );
    if (response.data.code === 200) {
      console.log(chalk.green(`✅ 挖矿签到成功 🎁`));
      return true;
    }
    throw new Error('签到失败: ' + (response.data.message || '未知错误'));
  } catch (error) {
    throw new Error(`签到失败: ${error.message}`);
  }
}

// 处理单个钱包
async function processWallet(wallet, index, total, proxyAgent, referralCode) {
  console.log(chalk.blue(`📌 处理钱包 ${index + 1}/${total}: ${wallet.address}`));
  try {
    const token = await performLogin(wallet, proxyAgent, referralCode);
    await performMiningCheckIn(token, proxyAgent);
    console.log(chalk.green(`✅ 钱包 ${wallet.address} 处理完成!`));
    return true;
  } catch (error) {
    console.log(chalk.red(`❌ 钱包 ${wallet.address} 处理失败: ${error.message}`));
    await fs.appendFile('error_log.txt', `${new Date().toISOString()} - 钱包 ${wallet.address} 失败: ${error.message}\n`);
    return false;
  }
}

// 主函数
async function runBot() {
  const wallets = await loadPrivateKeys();
  if (wallets.length === 0) {
    console.log(chalk.red(`❌ 未找到有效私钥，退出... 🚫`));
    return;
  }

  const proxies = await loadProxies();
  const referralCode = 'BMOCOEITA';
  const concurrency = 3; // 并发数量
  console.log(chalk.cyan(`ℹ️ 并发数量设置为: ${concurrency}`));

  async function executeCycle(cycleCount) {
    console.log(chalk.magenta(`\n🚀 开始第 ${cycleCount} 轮签到 - ${formatDateTime(new Date())} 🕒\n`));
    const startTime = Date.now();

    for (let i = 0; i < wallets.length; i += concurrency) {
      const batch = wallets.slice(i, i + concurrency);
      const promises = batch.map((wallet, batchIndex) => {
        const walletIndex = i + batchIndex;
        const proxy = proxies.length > 0 ? proxies[walletIndex % proxies.length] : null;
        const proxyAgent = proxy ? createProxyAgent(proxy) : null;
        if (proxy) console.log(chalk.yellow(`🌐 使用代理: ${proxy}`));
        return processWallet(wallet, walletIndex, wallets.length, proxyAgent, referralCode);
      });
      await Promise.all(promises);
      if (i + concurrency < wallets.length) await delay(2000); // 批次间延迟
    }

    const executionTime = (Date.now() - startTime) / 1000;
    console.log(chalk.green(`\n🎉 第 ${cycleCount} 轮签到完成!`));
    console.log(chalk.cyan(`⏱️ 执行时间: ${executionTime.toFixed(2)} 秒`));
    await fs.appendFile('execution_log.txt', `${formatDateTime(new Date())} - 第 ${cycleCount} 轮完成，耗时 ${executionTime.toFixed(2)} 秒\n`);
  }

  async function scheduleNextExecution(cycleCount = 1) {
    await executeCycle(cycleCount);
    const delayTime = 21 * 60 * 60 * 1000 + 10 * 60 * 1000; // 21小时10分钟
    const nextTime = new Date(Date.now() + delayTime);
    console.log(chalk.yellow(`\n⏰ 下次执行: ${formatDateTime(nextTime)}`));
    console.log(chalk.yellow(`⏳ 等待: ${formatTimeRemaining(delayTime)} 🕒`));
    await delay(delayTime);
    await scheduleNextExecution(cycleCount + 1);
  }

  await scheduleNextExecution(1);
}

runBot().catch(error => {
  console.log(chalk.red(`❌ 脚本崩溃: ${error.message}`));
});
