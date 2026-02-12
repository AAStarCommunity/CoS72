，个人用户就是可以查看社区广场和注册社区，管理个人面板
  - 未来我计划打包为一个chrome plugin，然后可以植入AirAccount的注册绑定登录
  - 完成核心基础功能，完全使用sdk lifecycley和l3,l4regression和各个demo，先demo，包括for-iri和已有的demo，demo目录的demo，提取而成
  - 给出一个社区启动的诉求和极简操作步骤：（SDK依赖合约先部署到op和主网）
    1. 快速启动一个链上社区，提供简单的启动界面，需要自己提供一个RPC（连接链上），国内需要测试（例如Alchemy RPC或替代品）
    2. 社区合约部署到op和主网（看gas），部署完成后，包括社区积分合约、社区Paymaster（看需要）、社区NFT合约
    3. 一次性部署，管理员界面：修改社区信息、积分配置、修改汇率、存入aPNTs（提供购买aPNTs入口，op上），其他可能功能
    4. 用户界面：注册、提示beta测试期，account address（如果升级为多签和社区游民版，会改变合约地址，提供工具）
    5. 常规的用户功能，提供友好简单的入口，和airaccount界面结合，包括账户+SBT（进入是global reputation）、社区list，进入是单个社区功能
    6. 单个社区功能入口（这些都需要单独开发）：任务、投票、Shop、知识库bot，预留入口
