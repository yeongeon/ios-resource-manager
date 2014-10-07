#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# @autor yeongeon_AT_gmail
#
import os, sys
import sqlite3
import hashlib
import shutil
from stat import *
from time import localtime, strftime
from re import *

#
# 현재 실행 경로
#
_SELF_PATH = os.path.dirname( os.path.abspath( __file__ ) )

#----------------------------------------------
# DEV : 경로를 접근해서 정보를 출력하는 함수입니다.
#----------------------------------------------
def findPath(path):
	for f in os.listdir(path):
		fpath = os.path.join(path, f)
		if os.path.isdir(fpath) is None:
			continue
			
		mode = os.stat(fpath).st_mode
		
		if S_ISDIR(mode):
			if search(".svn", fpath) is None:
				findPath(fpath)
		else:
			if search(".png", fpath) is not None:
				ctime = localtime(os.stat(fpath)[ST_CTIME])
				mtime = localtime(os.stat(fpath)[ST_MTIME])
				atime = localtime(os.stat(fpath)[ST_ATIME])
				
				fsize = os.stat(fpath)[ST_SIZE]
				
				str_ctime = strftime("%Y-%m-%d %H:%M:%S", ctime);
				str_mtime = strftime("%Y-%m-%d %H:%M:%S", mtime);
				str_atime = strftime("%Y-%m-%d %H:%M:%S", atime);
				
				str_crc = getCRC(fpath)
				
				if str_ctime==str_mtime is not None:
					print "", fpath
					#print "MODE:", mode
					print "CRC:", str_crc
					print "C:", str_ctime
					print "M:", str_mtime
					#print "A:", str_atime
					print "FSIZE:", fsize
					print "----------------------------------"



#----------------------------------------------
# Command : h
#----------------------------------------------
def doHelp():
	print "\n\nMade in YEONGEON\n\n"



#----------------------------------------------
# Command : 1
#----------------------------------------------
loopCheckNewCnt = 0
loopCheckUpdateCnt = 0
listNewForCheckUpdate = []
listUpdatedForCheckUpdate = []
def doCheckUpdate(path):
	global _SELF_PATH
	
	global loopCheckNewCnt
	global loopCheckUpdateCnt
	global listNewForCheckUpdate
	global listUpdatedForCheckUpdate
	
	# DB 연결
	db_path = "%s/%s" % (_SELF_PATH, "ResourceManager.db")
	db = sqlite3.connect(db_path, timeout=10)
	cursor = db.cursor()
	for f in os.listdir(path):
		fpath = os.path.join(path, f)
		if os.path.isdir(fpath) is None:
			continue
			
		mode = os.stat(fpath).st_mode
		
		if S_ISDIR(mode):
			if search(".svn", fpath) is None:
				doCheckUpdate(fpath)
		else:
			if search(".png", fpath) is not None:
				mtime = localtime(os.stat(fpath)[ST_MTIME])
				fsize = os.stat(fpath)[ST_SIZE]
				str_mtime = strftime("%Y-%m-%d %H:%M:%S", mtime);
				
				str_crc = getCRC(fpath)
				#print "fpath:%s, str_crc=%s" % (fpath, str_crc)
				
				arrNodes = fpath.split("/");
				fname = arrNodes.pop()
				fpath = "/".join(arrNodes)
				
				# 데이터 존재 체크
				#selectQuery = "SELECT * FROM ResourceManagerTbl WHERE filename='%s' AND created='%s' AND filesize='%d' ORDER BY created DESC LIMIT 1" % (fpath, str_mtime, fsize)
				#selectQuery = "SELECT * FROM ResourceManagerTbl WHERE filename='%s' AND crc='%s' ORDER BY created DESC LIMIT 1" % (fname, str_crc)
				selectQuery = "SELECT * FROM ResourceManagerTbl WHERE filename='%s' ORDER BY created DESC LIMIT 1" % (fname)
				cursor.execute(selectQuery)
				returnObject = cursor.fetchone()
				if returnObject is None:
					## DB에 없는 신규 파일로 처리
					# ./images@2x/write/write_tag02_on@2x.png					
					# 정보 출력
					result = "[NEW] %s" % (fname)
					listNewForCheckUpdate.append(result)
					#print result
					# New 카운트 증가
					loopCheckNewCnt+=1
				else:
					#print "[UPDATE] [str_mtime=%s, returnObject[2]=%s] [fsize=%s, returnObject[3]=%s]" % (str_mtime, returnObject[2], fsize, returnObject[3])
					
					## DB에는 있지만, 업데이트된 파일로 처리
					if str_crc!=returnObject[4]:
# 						# ./images@2x/write/write_tag02_on@2x.png
# 						arrNodes = returnObject[0].split("/");
# 						length = len(arrNodes)
# 						arrPaths = []
# 						for i, node in enumerate(arrNodes):
# 							if i>0 and i<(length-1) is not None:
# 								arrPaths.append(node)
						
						# 정보 출력
						result = "[UPDATE] %s\t\t\t\t\t%s" % (returnObject[0], returnObject[1])
						item = {"filename":returnObject[0], "filepath":returnObject[1], "msg":result }
						listUpdatedForCheckUpdate.append(item)
						#print result
						# Update 카운트 증가					
						loopCheckUpdateCnt+=1			
	# 종료
	cursor.close()
	db.close()
	


#----------------------------------------------
# Command : 2
#----------------------------------------------
def doPrintDB():
	global _SELF_PATH
	
	# DB 연결
	db_path = "%s/%s" % (_SELF_PATH, "ResourceManager.db")
	db = sqlite3.connect(db_path, timeout=10)
	cursor = db.cursor()

	# 데이터 꺼내기
	# 	select IP1,IP2,max(IP3) from yeon group by IP1,IP2;
	#selectQuery = "SELECT * FROM (SELECT * FROM ResourceManagerTbl ORDER BY created DESC) GROUP BY filename, filepath"
	selectQuery = "SELECT filename, filepath, MAX(created) AS created, filesize, crc, mdate FROM ResourceManagerTbl GROUP BY filename, crc ORDER BY mdate ASC"
	cursor.execute(selectQuery)
	loopRows = 0
	for row in cursor:
	    print "%s\t\t\t%s\t\t\t%s\t\t%s\t%s\t%s" % (row[0], row[1], row[2], row[3], row[4], row[5])
	    loopRows+=1
	
	print "# -------------------------------------------------------------------------"
	print "# Total Rows: %s" % (loopRows)
	print "# -------------------------------------------------------------------------\n\n"
	# 종료
	cursor.close()
	db.close()



#----------------------------------------------
# Command : 3
#----------------------------------------------
loopDiffWithDBCnt = 0
def doDiffWithDB(path):
	global _SELF_PATH
	
	global loopDiffWithDBCnt

	# DB 연결
	db_path = "%s/%s" % (_SELF_PATH, "ResourceManager.db")
	db = sqlite3.connect(db_path, timeout=10)
	cursor = db.cursor()
	
	for f in os.listdir(path):
		fpath = os.path.join(path, f)
		if os.path.isdir(fpath) is None:
			continue
			
		mode = os.stat(fpath).st_mode
		
		if S_ISDIR(mode):
			if search(".svn", fpath) is None:
				doDiffWithDB(fpath)
		else:
			if search(".png", fpath) is not None:
				mtime = localtime(os.stat(fpath)[ST_MTIME])
				fsize = os.stat(fpath)[ST_SIZE]
				str_mtime = strftime("%Y-%m-%d %H:%M:%S", mtime);
				
				str_crc = getCRC(fpath)
				#print str_crc
				
				arrNodes = fpath.split("/");
				fname = arrNodes.pop()
				fpath = "/".join(arrNodes)
				
				# 데이터 존재 체크
				selectQuery = "SELECT * FROM ResourceManagerTbl WHERE filename='%s' AND crc='%s' ORDER BY created DESC LIMIT 1" % (fname, str_crc)
				cursor.execute(selectQuery)
				returnObject = cursor.fetchone()
				if returnObject is None:
					print "%s\t\t\t%s\t\t\t%s\t\t%s" % (fname, fpath, str_mtime, str_crc)
					loopDiffWithDBCnt+=1
						
	# 종료
	cursor.close()
	db.close()





#----------------------------------------------
# Command : 4
#----------------------------------------------
loopInsertedCnt = 0
def doInsertUpdateDB(path):
	global _SELF_PATH
	
	global loopInsertedCnt
	
	# DB 연결
	db_path = "%s/%s" % (_SELF_PATH, "ResourceManager.db")
	db = sqlite3.connect(db_path, timeout=10)
	cursor = db.cursor()
	
	for f in os.listdir(path):
		fpath = os.path.join(path, f)
		if os.path.isdir(fpath) is None:
			continue

		mode = os.stat(fpath).st_mode
		
		if S_ISDIR(mode):
			if search(".svn", fpath) is None:
				doInsertUpdateDB(fpath)
		else:
			if search(".png", fpath) is not None:
				mtime = localtime(os.stat(fpath)[ST_MTIME])
				fsize = os.stat(fpath)[ST_SIZE]
				str_mtime = strftime("%Y-%m-%d %H:%M:%S", mtime);
				
				str_crc = getCRC(fpath)
				#print str_crc
				
				arrNodes = fpath.split("/");
				fname = arrNodes.pop()
				fpath = "/".join(arrNodes)
					
				# 데이터 존재 체크
				selectQuery = "SELECT * FROM ResourceManagerTbl WHERE filename='%s' AND crc='%s' ORDER BY created DESC LIMIT 1" % (fname, str_crc)
				cursor.execute(selectQuery)
				returnObject = cursor.fetchone()
				if returnObject is None:
					
					# 데이터 INSERT
					insertQuery = "INSERT INTO ResourceManagerTbl (filename, filepath, created, filesize, crc) VALUES (?, ?, ?, ?, ?)"
					result = cursor.execute(insertQuery, (fname, fpath, str_mtime, fsize, str_crc))
					#print "result:%s" % (result)
					db.commit()
					loopInsertedCnt += 1
	
	print "#_inserted : %d" % (loopInsertedCnt)
	# 종료
	cursor.close()
	db.close()




#----------------------------------------------
# Command : 5
#----------------------------------------------
def doPrintCRC(path):
	if os.path.isdir(path):
		for f in os.listdir(path):
			fpath = os.path.join(path, f)
			if os.path.isdir(fpath) is None:
				continue
				
			mode = os.stat(fpath).st_mode
			
			if S_ISDIR(mode):
				if search(".svn", fpath) is None:
					doPrintCRC(fpath)
			else:
				if os.path.isfile(fpath) is None:
					print "#존재하지 않는 파일입니다 :%s" % (fpath)
					return
				str_crc = getCRC(fpath)
				print "%s\t\t\t\t%s" % (fpath, str_crc)
	else:
		if os.path.isfile(path) is None:
			print "#존재하지 않는 파일입니다 :%s" % (path)
			return
		str_crc = getCRC(path)
		print "%s\t\t\t\t%s" % (path, str_crc)		
	

#----------------------------------------------
# Command : 6_1
#----------------------------------------------	
def doDiffListFolder(path):
	aFile = []
	if os.path.isdir(path):
		for f in os.listdir((path)):
			fpath = os.path.join((path), f)
			if os.path.isdir(fpath) is None:
				continue
	
			mode = os.stat(fpath).st_mode
			
			if S_ISDIR(mode):
				if search(".svn", fpath) is None:
					doDiffListFolder(fpath)
			else:
				if os.path.isfile(fpath) is None:
					print "#존재하지 않는 파일입니다 :%s" % (fpath)
					return
				filename = os.path.basename(fpath)
				aFile.append(filename)
	
	return aFile
	
	
#----------------------------------------------
# Command : 6
#----------------------------------------------
def doCrawlFile(path):
	for f in os.listdir(path):
		fpath = os.path.join(path, f)
		if os.path.isdir(fpath) is None:
			continue
			
		mode = os.stat(fpath).st_mode
		
		if S_ISDIR(mode):
			if search(".svn", fpath) is None:
				doCrawlFile(fpath)
		else:
			if search(".m", fpath) is not None:
				try:
					fp = open(fpath)  # 파일 열기
				
					for s in fp:
						print s        # 1줄씩 출력
				
					fp.close()        # 파일 닫기
				except IOError:
					print >> sys.stderr, '파일을 열 수 없습니다.'
				
				
				
	
#----------------------------------------------
# 화면 Clear 처리하는 함수입니다.
#----------------------------------------------	
def doCls():
    os.system(['clear','cls'][os.name == 'nt'])




#----------------------------------------------
# 파일의 해쉬MD5 값을 반환하는 함수힙니다.
# (파일 CRC 반환)
#----------------------------------------------
def getCRC(fpath):
	m = hashlib.md5()
	for line in open(fpath, 'rb'):
		m.update(line)
	return m.hexdigest()



#----------------------------------------------
# 무한루프를 돌면서 다음 명령어를 입력받는 함수입니다.
#----------------------------------------------
loopMainCnt=0
def mainLoop(argv):
	global _SELF_PATH
	
	global loopMainCnt
	
	global loopCheckNewCnt
	global loopCheckUpdateCnt
	global listNewForCheckUpdate
	global listUpdatedForCheckUpdate
	
	global loopDiffWithDBCnt
	
	global loopInsertedCnt
	
	
	resultMap={
	  "h":doHelp,
	  "1":doCheckUpdate,
	  "2":doPrintDB,
	  "3":doDiffWithDB,
	  "4":doInsertUpdateDB,
	  "5":doPrintCRC,
	  "6":doCrawlFile
	}
	while True:
		#화면 cls 처리
		if loopMainCnt==0 is not None:
			doCls()
		
		#-----------------------------
		# 기본적으로 디비가 없으면 생성한다.
		#-----------------------------
		# DB 연결
		db_path = "%s/%s" % (_SELF_PATH, "ResourceManager.db")
		db = sqlite3.connect(db_path, timeout=10)
		cursor = db.cursor()
		# 테이블 생성
		createQuery = "CREATE TABLE IF NOT EXISTS ResourceManagerTbl "
		createQuery+= "(filename TEXT, "
		createQuery+= "filepath TEXT, "
		createQuery+= "created TEXT, "
		createQuery+= "filesize TEXT, " 
		createQuery+= "crc TEXT, " 
		createQuery+= "mdate TEXT DEFAULT CURRENT_TIMESTAMP, "
		createQuery+= "PRIMARY KEY (filename, crc))"
		result = cursor.execute(createQuery);
		#print "result:%s" % (result)
		db.commit()
		# 종료
		cursor.close()
		db.close()

		
		#-----------------------------
		# 가이드문 출력
		#-----------------------------
		msg="\n====================================================================================\n"
		msg+="************************** Resource Manager Command Center *************************\n"
		msg+="====================================================================================\n"
		msg+="h : 도움말(Help)\n\n"
		msg+="1 : 업데이트 파일 확인 및 업데이트된 파일 복사(File Check and copy for Update)\n\t - FAQ:새로운 파일 어디에 추가하나요? 자동으로 복사할수는 없나요?\n\n"
		msg+="2 : DB정보 출력(Print List in DB)\n\t - FAQ:현재 DB의 데이터를 보여주세요.\n\n"
		msg+="3 : DB와 현재 파일중에서 변경된 목록 출력(Diff between DB and Path)\n\t - FAQ:현재 DB의 데이터와 폴더를 비교해서 변동사항이 있는것들을 보여주세요.\n\n"
		msg+="4 : 현재 파일 목록 DB에 입력/업데이트(Update File infos to DB)\n\t - FAQ:폴더의 파일 정보를 최신 DB데이터로 처리해주세요.\n\n"
		msg+="5 : 파일 CRC 값을 출력해주세요.(Print CRC of file or files in path)\n\t - FAQ:파일의 CRC값이 궁금해요.\n\n"
		msg+="6 : 특정 폴더내의 파일이 소스에 이용되고 있는지 확인해주세요.\n\t - FAQ:폴더내의 파일들이 소스에서 쓰이고 있는지 확인하고 싶어요.\n\n"
		msg+="7 : 소스 내에서 사용된 .png 파일 리스트를 생성해주세요.\n\t - FAQ:소스로 구현된 .png 파일이 뭔지 궁금합니다.(소스 크롤링, png파일명 DB화)\n\n"
		msg+="8 : 소스 내에서 사용된 .png 파일이(7번) 특정 폴더에 존재하고 있는지 확인해주세요.\n\t - FAQ:소스에서 정의된 파일들이 특정 폴더내에 있긔 없긔 확인해줘요.\n\n"
		msg+="q : 종료(Quit)\n"
		msg+="====================================================================================\n"
		msg+="선택하세요:"
		inputKey = raw_input(msg).strip()
		
		### q: 종료
		if inputKey=="q" is not None:
			break;
		
		### 1: 업데이트 파일 확인
		elif inputKey=="1" is not None: 
			msg1="Input Target Path \n<확인할 폴더를 여기에 Drop하세요-for mac>:"
			inputKey1 = raw_input(msg1).strip()
			if inputKey1=="" is not None:
				continue
				
			msg1_1="# 입력된 타겟 경로는 '%s' 입니다.\n" % (inputKey1)
			msg1_1+="# 계속 진행하시겠습니까? ([Y]es, [N]o):"
			inputKey1_1 = raw_input(msg1_1).strip()
			inputKey1_1 = inputKey1_1.upper()
			
			if inputKey1_1=="Y" or inputKey1_1=="YES":
				# 실행시 초기화
				loopCheckNewCnt=0
				loopCheckUpdateCnt=0
				listNewForCheckUpdate = []
				listUpdatedForCheckUpdate = []
				
				doCheckUpdate(inputKey1)
				print "----------------------------------------------"
				print "@ Checked New\t\t: %d" % (loopCheckNewCnt)
				print "@ Checked Update\t: %d" % (loopCheckUpdateCnt)
				print "----------------------------------------------\n"	
				
				if loopCheckNewCnt>0 is not None:
					msg1_2="# NEW 파일이 '%d'개 입니다.\n" % (loopCheckNewCnt)
					msg1_2+="# 출력할까요? ([Y]es, [N]o):"
					inputKey1_2 = raw_input(msg1_2).strip()
					inputKey1_2 = inputKey1_2.upper()
					if inputKey1_2=="Y" or inputKey1_2=="YES" or inputKey1_2=="":
						print "----------------------------------------------"
						for txt in listNewForCheckUpdate:
							print txt
						print "\n\n"
							
				if loopCheckUpdateCnt>0 is not None:
					msg1_3="==============================================\n"
					msg1_3+="# UPDATE로 예상되는 파일이 '%d'개 입니다.\n" % (loopCheckUpdateCnt)
					msg1_3+="# 출력할까요? ([Y]es, [N]o):"
					inputKey1_3 = raw_input(msg1_3).strip()
					inputKey1_3 = inputKey1_3.upper()
					if inputKey1_3=="Y" or inputKey1_3=="YES" or inputKey1_3=="":
						print "----------------------------------------------"
						for item in listUpdatedForCheckUpdate:
							print item.get("msg")
						print "\n\n"
						
						
					msg1_4="==============================================\n"
					msg1_4+="# UPDATE로 예상되는 파일 '%d'개를 자동 복사 처리할까요?\n" % (loopCheckUpdateCnt)
					msg1_4+="# 덮어쓰기로 복사할까요? ([Y]es, [N]o):"
					inputKey1_4 = raw_input(msg1_4).strip()
					inputKey1_4 = inputKey1_4.upper()
					if inputKey1_4=="Y" or inputKey1_4=="YES":
						print "----------------------------------------------"
						for item in listUpdatedForCheckUpdate:
							orgFile = "%s/%s" % (inputKey1, item.get("filename") )
							desPath = "%s/." % (item.get("filepath") )
							
							if os.path.isfile(orgFile) is None:
								print "#존재하지 않는 파일입니다 :%s" % (orgFile)
								continue
							
							if os.path.isdir(desPath) is None:
								print "#존재하지 않는 경로입니다 :%s" % (desPath)
								continue
							
							shutil.copy(orgFile, desPath)
							doInsertUpdateDB(desPath)
							
							print "copy %s %s" % (orgFile, desPath)
							
						print "\n\n"

					
			
		### 3: DB와 현재 파일중에서 변경된 목록 출력
		elif inputKey=="3" is not None: 
			msg3="Input Target Path [Default: %s ]:" % (_SELF_PATH)
			inputKey3 = _SELF_PATH #raw_input(msg3).strip()
			if inputKey3=="" is not None:
				inputKey3 = _SELF_PATH
			
			msg3_1="# 입력된 타겟 경로는 '%s' 입니다.\n" % (inputKey3)
			msg3_1+="# 계속 진행하시겠습니까? ([Y]es, [N]o):"
			inputKey3_1 = raw_input(msg3_1).strip()
			inputKey3_1 = inputKey3_1.upper()
			
			if inputKey3_1=="Y" or inputKey3_1=="YES" or inputKey3_1=="":
				loopDiffWithDBCnt=0
				
				doDiffWithDB(inputKey3)
				print "----------------------------------------------"
				print "@ Diff : %d" % (loopDiffWithDBCnt)
				print "----------------------------------------------\n\n"
					
		### 4: 현재 파일 목록 DB에 입력/업데이트
		elif inputKey=="4" is not None: 
			msg4="Input Target Path [Default: %s ]:" % (_SELF_PATH)
			inputKey4 = _SELF_PATH #raw_input(msg4).strip()
			if inputKey4=="" is not None:
				inputKey4 = _SELF_PATH
			
			msg4_1="# 입력된 타겟 경로는 '%s' 입니다.\n" % (inputKey4)
			msg4_1+="# 정말 작업을 수행하시겠습니까? ([Y]es, [N]o):"
			inputKey4_1 = raw_input(msg4_1).strip()
			inputKey4_1 = inputKey4_1.upper()
			
			if inputKey4_1=="Y" or inputKey4_1=="YES":
				loopInsertedCnt=0
				
				doInsertUpdateDB(inputKey4)
				print "----------------------------------------------"
				print "@ INSERTED : %d" % (loopInsertedCnt)
				print "----------------------------------------------\n\n"
		
		### 5: 파일 CRC 값을 출력
		elif inputKey=="5" is not None:
			msg5="Input Target File:"
			inputKey5 = raw_input(msg5).strip()
			print "----------------------------------------------"
			doPrintCRC(inputKey5)
			print "----------------------------------------------\n\n"
		
		### 6: 폴더 내의 파일명을 소스에서 검색
		elif inputKey=="6" is not None:
			#1.input target path
			msg6="Input Target File:"
			inputKey6 = raw_input(msg6).strip()
			print "----------------------------------------------"
			doCrawlFile(inputKey6)
			print "----------------------------------------------\n\n"
			
			#2.make a list of file names in target path by memory
			
			#3.crawl sources in source path
			
			#4.loop in No.3 and match with filename and content of source file
			
			#5.remain a history for No.4
			print "개발중입니다."
			
		### 7: 소스내의 파일명을 저장
		elif inputKey=="7" is not None:
			#1.crawl a filename in source files
			
			#2.save a filenames to DB
			print "개발중입니다."
			
		### 8: 저장된 파일명(7번)이 실제로 폴더내에 존재하는지 확인
		elif inputKey=="8" is not None:
			#1.select DB
			
			#2.fetch DB
			
			#3.compare with files in path and fetched data 
			print "개발중입니다."
		
		### 그냥 엔터 처리
		elif inputKey=="" is not None:
			doCls()
			continue
		
		### 나머지는 해시맵에 선언된 함수 수행		
		else:
			if resultMap.get(inputKey) is None:
				continue
			else:
				result=resultMap.get(inputKey)()
  
  
  		loopMainCnt+=1


#----------------------------------------------
# 최초 실행 함수입니다.
#----------------------------------------------
if __name__ == '__main__':
	#if len(sys.argv)>1:
		#findPath(sys.argv[1])
	#else:
		mainLoop(sys.argv)
		#print "[USAGE] ResourceManager"



