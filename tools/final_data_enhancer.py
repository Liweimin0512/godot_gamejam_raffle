#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
游戏抽奖数据增强器（最终版）
- 修复开发日志信息显示错误
- 标准化图片命名
- 清理数据格式问题
"""

import requests
from bs4 import BeautifulSoup
import csv
import os
import re
import time
import shutil
import hashlib
import json
from urllib.parse import urljoin, urlparse, quote_plus

class FinalDataEnhancer:
    def __init__(self):
        # 初始化会话和目录
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })
        
        self.jam_url = "https://itch.io/jam/httpsgithubcomli-game-academy-craft-2"
        
        # 初始化目录
        self.base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.image_dir = os.path.join(self.base_dir, 'assets', 'entries')
        self.debug_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'debug')
        self.cache_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cache')
        
        for directory in [self.image_dir, self.debug_dir, self.cache_dir]:
            os.makedirs(directory, exist_ok=True)
        
        # 初始化缓存
        self.cache_file = os.path.join(self.cache_dir, 'game_info_cache.json')
        self.game_cache = self.load_cache()
        
        # 计数器
        self.game_counter = 1
        
        # 跟踪已处理的游戏
        self.processed_games = set()
        
        # 跟踪游戏ID和图片名映射
        self.game_id_map = {}
    
    def load_cache(self):
        """加载缓存数据"""
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    cache = json.load(f)
                print(f"从缓存加载了 {len(cache)} 个游戏信息")
                return cache
            except Exception as e:
                print(f"加载缓存失败: {e}")
        return {}
    
    def save_cache(self):
        """保存缓存数据"""
        try:
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.game_cache, f, ensure_ascii=False, indent=2)
            print(f"保存了 {len(self.game_cache)} 个游戏信息到缓存")
        except Exception as e:
            print(f"保存缓存失败: {e}")
    
    def get_soup(self, url, timeout=30):
        """获取网页内容并解析"""
        try:
            print(f"请求URL: {url}")
            response = self.session.get(url, timeout=timeout)
            
            if response.status_code != 200:
                print(f"请求失败: {url}, 状态码: {response.status_code}")
                return None
            
            html_content = response.text
            
            # 尝试修复编码问题
            if '&#' in html_content:
                from html import unescape
                html_content = unescape(html_content)
            
            return BeautifulSoup(html_content, 'html.parser')
        except Exception as e:
            print(f"请求异常: {e}")
            return None
    
    def normalize_string(self, s):
        """规范化字符串，用于比较"""
        if not s:
            return ""
        s = s.lower()
        s = re.sub(r'[^\w\s]', '', s)
        s = re.sub(r'\s+', ' ', s).strip()
        return s
    
    def string_similarity(self, s1, s2):
        """计算两个字符串的相似度"""
        if not s1 or not s2:
            return 0
            
        # 规范化
        s1 = self.normalize_string(s1)
        s2 = self.normalize_string(s2)
        
        # 分词
        words1 = set(s1.split())
        words2 = set(s2.split())
        
        # 如果其中一个是空集，返回0
        if not words1 or not words2:
            return 0
        
        # 计算共同单词
        common = words1.intersection(words2)
        
        # Jaccard相似度
        return len(common) / len(words1.union(words2))
    
    def find_game_in_jam(self, title, author=""):
        """在Game Jam页面上查找游戏"""
        # 获取游戏条目页面
        soup = self.get_soup(f"{self.jam_url}/entries")
        if not soup:
            return None
        
        # 查找所有游戏条目
        game_cells = soup.select('.game_cell, .entry')
        print(f"在Jam中找到 {len(game_cells)} 个游戏条目")
        
        best_match = None
        best_score = 0
        
        for cell in game_cells:
            # 获取标题
            cell_title_elem = cell.select_one('.title, .name')
            if not cell_title_elem:
                continue
                
            cell_title = cell_title_elem.text.strip()
            
            # 获取作者
            cell_author_elem = cell.select_one('.user_link, .author')
            cell_author = cell_author_elem.text.strip() if cell_author_elem else ""
            
            # 计算相似度
            title_sim = self.string_similarity(title, cell_title)
            
            # 如果有作者，考虑作者相似度
            author_sim = 0
            if author and cell_author:
                author_sim = self.string_similarity(author, cell_author)
            
            # 综合得分 (标题权重更高)
            score = title_sim * 0.8 + author_sim * 0.2
            
            if score > best_score:
                # 找到游戏链接
                link_elem = cell.select_one('a.title, a.entry_thumbnail, .title a')
                if link_elem and link_elem.get('href'):
                    best_score = score
                    best_match = (link_elem.get('href'), score)
                    print(f"可能匹配: {cell_title} by {cell_author} (分数: {score:.2f})")
        
        if best_match and best_score > 0.5:  # 设置较高阈值
            print(f"找到最佳匹配，分数: {best_score:.2f}")
            return best_match[0]
        
        return None
    
    def search_on_itch_io(self, title, author=""):
        """在itch.io上搜索游戏"""
        search_query = title
        if author:
            search_query += f" {author}"
        
        # 构造搜索URL
        search_url = f"https://itch.io/search?q={quote_plus(search_query)}"
        
        soup = self.get_soup(search_url)
        if not soup:
            return None
        
        # 查找所有游戏结果
        game_cells = soup.select('.game_cell')
        if not game_cells:
            print(f"itch.io搜索未找到: {title}")
            return None
        
        best_match = None
        best_score = 0
        
        for cell in game_cells:
            cell_title_elem = cell.select_one('.title')
            if not cell_title_elem:
                continue
                
            cell_title = cell_title_elem.text.strip()
            
            # 获取作者
            cell_author_elem = cell.select_one('.user_link')
            cell_author = cell_author_elem.text.strip() if cell_author_elem else ""
            
            # 计算相似度
            title_sim = self.string_similarity(title, cell_title)
            
            # 如果有作者，考虑作者相似度
            author_sim = 0
            if author and cell_author:
                author_sim = self.string_similarity(author, cell_author)
            
            # 综合得分
            score = title_sim * 0.7 + author_sim * 0.3
            
            if score > best_score:
                link_elem = cell_title_elem.find('a')
                if link_elem and link_elem.get('href'):
                    best_score = score
                    best_match = (link_elem.get('href'), score)
                    print(f"itch.io搜索匹配: {cell_title} by {cell_author} (分数: {score:.2f})")
        
        if best_match and best_score > 0.4:
            print(f"itch.io搜索最佳匹配，分数: {best_score:.2f}")
            return best_match[0]
        
        return None
    
    def get_game_id(self, url):
        """从URL中提取游戏ID"""
        if not url:
            return None
            
        # 尝试不同的正则模式提取ID
        patterns = [
            r'/game/(\d+)',  
            r'/(\d+)/',      
            r'-(\d+)$',      
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        
        # 使用URL路径的最后一部分
        path = urlparse(url).path.strip('/')
        if '/' in path:
            slug = path.split('/')[-1]
            return slug
        elif path:
            return path
        
        # 最后的备选方案
        return f"game_{self.game_counter}"
    
    def download_game_image(self, game_url, game_id):
        """从游戏页面下载封面图片"""
        if not game_url or not game_id:
            return None
            
        # 检查缓存
        if game_id in self.game_cache and 'image' in self.game_cache[game_id]:
            cached_image = self.game_cache[game_id]['image']
            image_path = os.path.join(self.base_dir, cached_image.replace('res://', ''))
            if os.path.exists(image_path):
                print(f"使用缓存的图片: {cached_image}")
                return cached_image
        
        # 获取游戏页面
        soup = self.get_soup(game_url)
        if not soup:
            return None
        
        # 尝试不同的选择器找到图片
        image_selectors = [
            '.screenshot_list img:first-child',
            '.game_cover img',
            '.game_header_image_widget img',
            '.thumb_link img',
            '.game_thumb img',
            '.screenshot img'
        ]
        
        for selector in image_selectors:
            img_elem = soup.select_one(selector)
            if img_elem:
                src = img_elem.get('src') or img_elem.get('data-src')
                if src:
                    return self.download_image(src, game_id)
        
        print(f"未找到游戏图片: {game_url}")
        return None
    
    def download_image(self, image_url, game_id):
        """下载并保存图片"""
        if not image_url or not game_id:
            return None
            
        try:
            # 获取图片扩展名
            parsed_url = urlparse(image_url)
            orig_ext = os.path.splitext(parsed_url.path)[1]
            ext = orig_ext if orig_ext else '.png'  # 默认扩展名
            
            # 生成标准化文件名
            filename = f"game_{game_id}{ext}"
            filepath = os.path.join(self.image_dir, filename)
            
            # 检查文件是否已存在
            if os.path.exists(filepath):
                print(f"图片已存在: {filename}")
                return f"res://assets/entries/{filename}"
            
            # 下载图片
            print(f"下载图片: {image_url} -> {filename}")
            response = self.session.get(image_url, stream=True, timeout=30)
            if response.status_code == 200:
                with open(filepath, 'wb') as f:
                    for chunk in response.iter_content(1024):
                        f.write(chunk)
                return f"res://assets/entries/{filename}"
            else:
                print(f"下载图片失败: {response.status_code}")
                return None
        except Exception as e:
            print(f"下载图片出错: {e}")
            return None
    
    def get_game_devlogs(self, url):
        """获取游戏的开发日志"""
        if not url:
            return {"has_devlog": "没有", "devlogs": []}
            
        # 获取游戏页面
        soup = self.get_soup(url)
        if not soup:
            return {"has_devlog": "没有", "devlogs": []}
            
        # 查找开发日志链接
        devlog_link = soup.select_one('a[href*="devlog"]')
        if not devlog_link:
            return {"has_devlog": "没有", "devlogs": []}
            
        devlog_url = devlog_link.get('href')
        if not devlog_url:
            return {"has_devlog": "没有", "devlogs": []}
            
        # 获取开发日志列表
        devlog_soup = self.get_soup(devlog_url)
        if not devlog_soup:
            return {"has_devlog": "有", "devlogs": []}
            
        devlog_posts = []
        post_elems = devlog_soup.select('.post_grid_item, .blog_post')
        
        for post in post_elems[:5]:  # 只获取前5个，避免太多
            post_link = post.select_one('a')
            post_title = post.select_one('.post_title, .post_name')
            
            if post_link and post_title:
                post_data = {
                    'name': post_title.text.strip(),
                    'url': post_link.get('href')
                }
                devlog_posts.append(post_data)
        
        return {
            "has_devlog": "有",
            "devlogs": devlog_posts
        }
    
    def get_game_details(self, game_url):
        """获取游戏的详细信息"""
        if not game_url:
            return {}
            
        # 提取游戏ID
        game_id = self.get_game_id(game_url)
        if not game_id:
            print(f"无法提取游戏ID: {game_url}")
            return {}
            
        # 检查缓存
        if game_id in self.game_cache:
            print(f"使用缓存的游戏信息: {game_id}")
            return self.game_cache[game_id]
            
        print(f"获取游戏详情: {game_url} (ID: {game_id})")
        
        soup = self.get_soup(game_url)
        if not soup:
            return {}
            
        game_info = {
            'id': game_id,
            'url': game_url
        }
        
        # 获取游戏标题
        title_elem = soup.select_one('.game_title, .title')
        if title_elem:
            game_info['title'] = title_elem.text.strip()
        
        # 获取作者
        author_elem = soup.select_one('.game_author a, .user_row a')
        if author_elem:
            game_info['user'] = author_elem.text.strip()
        
        # 获取开发日志信息
        devlog_info = self.get_game_devlogs(game_url)
        game_info['has_devlog'] = devlog_info['has_devlog']
        game_info['devlogs'] = devlog_info['devlogs']
        
        # 下载游戏图片
        image_path = self.download_game_image(game_url, game_id)
        if image_path:
            game_info['image'] = image_path
        
        # 保存到缓存
        self.game_cache[game_id] = game_info
        self.save_cache()
        
        return game_info
    
    def standardize_image_path(self, entry):
        """标准化图片路径"""
        if not entry.get('id') or not entry.get('image'):
            return entry
        
        # 检查图片路径是否需要更新
        image_path = entry['image']
        if 'game_' in image_path:
            return entry  # 已经是标准化的路径
        
        # 提取旧图片文件名
        old_filename = os.path.basename(image_path)
        old_path = os.path.join(self.base_dir, image_path.replace('res://', ''))
        
        if not os.path.exists(old_path):
            print(f"旧图片不存在: {old_path}")
            return entry
        
        # 创建新的文件名
        ext = os.path.splitext(old_filename)[1]
        new_filename = f"game_{entry['id']}{ext}"
        new_path = os.path.join(self.image_dir, new_filename)
        
        # 复制图片到新命名
        try:
            if not os.path.exists(new_path):
                shutil.copy2(old_path, new_path)
                print(f"重命名图片: {old_filename} -> {new_filename}")
            
            # 更新条目的图片路径
            entry['image'] = f"res://assets/entries/{new_filename}"
            
        except Exception as e:
            print(f"重命名图片失败: {e}")
        
        return entry
    
    def reorganize_image_files(self):
        """重新组织图片文件，使用标准命名"""
        print("清理和重组图片目录...")
        
        # 处理现有图片
        for filename in os.listdir(self.image_dir):
            if filename.endswith('.import'):
                continue
                
            file_path = os.path.join(self.image_dir, filename)
            if not os.path.isfile(file_path):
                continue
            
            # 找到非标准化的文件
            if not filename.startswith('game_'):
                print(f"找到非标准化的图片: {filename}")
    
    def process_entries(self, csv_file):
        """处理CSV文件中的条目，增强数据"""
        entries = []
        
        try:
            # 读取CSV文件
            with open(csv_file, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                headers = next(reader)  # 读取标题行
                
                # 找到各列索引
                title_idx = headers.index('游戏名称') if '游戏名称' in headers else 0
                id_idx = headers.index('游戏ID') if '游戏ID' in headers else -1
                url_idx = headers.index('游戏链接') if '游戏链接' in headers else -1
                devlog_idx = headers.index('是否有开发日志') if '是否有开发日志' in headers else -1
                author_idx = headers.index('作者') if '作者' in headers else -1
                review_idx = headers.index('主观评价') if '主观评价' in headers else -1
                image_idx = headers.index('图片') if '图片' in headers else -1
                weight_idx = headers.index('权重') if '权重' in headers else -1
                
                # 读取并处理每一行
                for row in reader:
                    if not row or len(row) <= title_idx or not row[title_idx]:
                        continue
                    
                    title = row[title_idx]
                    print(f"\n处理游戏: {title}")
                    
                    # 基本信息
                    entry = {
                        'title': title,
                        'id': row[id_idx] if id_idx >= 0 and id_idx < len(row) and row[id_idx] else "",
                        'url': row[url_idx] if url_idx >= 0 and url_idx < len(row) and row[url_idx] else "",
                        'has_devlog': row[devlog_idx] if devlog_idx >= 0 and devlog_idx < len(row) else "",
                        'user': row[author_idx] if author_idx >= 0 and author_idx < len(row) else "",
                        'review': row[review_idx] if review_idx >= 0 and review_idx < len(row) else "",
                        'image': row[image_idx] if image_idx >= 0 and image_idx < len(row) else "",
                        'weight': row[weight_idx] if weight_idx >= 0 and weight_idx < len(row) else "1",
                        'devlogs': []
                    }
                    
                    # 如果没有游戏URL，尝试寻找
                    if not entry['url']:
                        author = entry['user']
                        
                        # 尝试在Game Jam页面查找
                        game_url = self.find_game_in_jam(title, author)
                        
                        # 如果没找到，在itch.io上搜索
                        if not game_url:
                            game_url = self.search_on_itch_io(title, author)
                        
                        if game_url:
                            print(f"找到游戏链接: {game_url}")
                            entry['url'] = game_url
                            
                            # 如果没有ID，从URL提取
                            if not entry['id']:
                                entry['id'] = self.get_game_id(game_url)
                    
                    # 如果有URL，获取完整信息
                    if entry['url']:
                        game_details = self.get_game_details(entry['url'])
                        
                        if game_details:
                            # 只更新缺失的信息
                            if not entry['id'] and 'id' in game_details:
                                entry['id'] = game_details['id']
                                
                            # 更新开发日志信息
                            if ('has_devlog' not in entry or not entry['has_devlog']) and 'has_devlog' in game_details:
                                entry['has_devlog'] = game_details['has_devlog']
                                
                            if 'devlogs' in game_details:
                                entry['devlogs'] = game_details['devlogs']
                                
                            # 如果有新图片，更新
                            if 'image' in game_details and game_details['image'] and (not entry['image'] or entry['image'] == ""):
                                entry['image'] = game_details['image']
                    
                    # 如果仍然没有ID，生成一个
                    if not entry['id']:
                        unique_id = hashlib.md5(title.encode('utf-8')).hexdigest()[:8]
                        entry['id'] = unique_id
                        print(f"为{title}生成唯一ID: {unique_id}")
                    
                    # 确保图片路径使用标准命名
                    entry = self.standardize_image_path(entry)
                    
                    # 添加到结果列表
                    entries.append(entry)
                    self.processed_games.add(title)
                    self.game_counter += 1
                    
                    # 等待一下，避免请求过快
                    time.sleep(0.5)
            
            return entries
            
        except Exception as e:
            print(f"处理CSV文件时出错: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def save_enhanced_csv(self, entries, output_file):
        """保存增强后的数据到CSV文件"""
        if not entries:
            print("没有找到游戏数据，无法保存CSV")
            return False
        
        try:
            # 定义CSV字段
            fieldnames = [
                '游戏名称', 
                '游戏ID', 
                '游戏链接', 
                '是否有开发日志', 
                '开发日志', 
                '作者', 
                '主观评价', 
                '图片', 
                '权重'
            ]
            
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(fieldnames)
                
                for entry in entries:
                    # 处理开发日志链接
                    devlogs_str = ""
                    if entry.get('devlogs'):
                        devlog_items = []
                        for devlog in entry['devlogs']:
                            devlog_items.append(f"{devlog['name']}|{devlog['url']}")
                        devlogs_str = ";".join(devlog_items)
                    
                    writer.writerow([
                        entry.get('title', ""),
                        entry.get('id', ""),
                        entry.get('url', ""),
                        entry.get('has_devlog', ""),
                        devlogs_str,
                        entry.get('user', ""),
                        entry.get('review', ""),
                        entry.get('image', ""),
                        entry.get('weight', "1")
                    ])
            
            print(f"成功保存数据到 {output_file}")
            return True
        except Exception as e:
            print(f"保存CSV时出错: {e}")
            return False

def main():
    # 输入和输出文件路径
    input_csv = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'config', 'entries.csv')
    output_csv = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'config', 'enhanced_entries.csv')
    
    # 创建数据增强器
    enhancer = FinalDataEnhancer()
    
    # 重新组织图片文件
    enhancer.reorganize_image_files()
    
    # 处理CSV文件中的条目
    enhanced_entries = enhancer.process_entries(input_csv)
    
    # 保存增强后的数据
    if enhanced_entries:
        enhancer.save_enhanced_csv(enhanced_entries, output_csv)
        print(f"成功处理了 {len(enhanced_entries)} 个游戏条目")
    else:
        print("没有找到有效的游戏条目")
    
    print("数据增强完成!")

if __name__ == "__main__":
    main()
